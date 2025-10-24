const helpers = require("../helpers.cjs")
const moment = require("moment")
const prompt = require("inquirer").createPromptModule()

const { Witnet } = require("@witnet/sdk")
const { utils, WitOracle } = require("../../../dist/src")

const { DEFAULT_LIMIT, DEFAULT_SINCE } = helpers

module.exports = async function (options = {}, args = []) {
  [args] = helpers.deleteExtraFlags(args)

  const { limit, offset, parse, push, since } = options

  const witOracle = await WitOracle.fromJsonRpcUrl(
    `http://127.0.0.1:${options?.port || 8545}`,
    options?.signer,
  )

  const { address, network, provider } = witOracle
  helpers.traceHeader(`${network.toUpperCase()}`, helpers.colors.lcyan)

  const symbol = utils.getEvmNetworkSymbol(network)
  const artifact = await witOracle.getEvmImplClass()
  const version = await witOracle.getEvmImplVersion()
  console.info(`> ${helpers.colors.lwhite(artifact)}: ${helpers.colors.lblue(address)} ${helpers.colors.blue(`[ v${version} ]`)}`)

  if (push) {
    const drTxHash = push
    if (!utils.isHexStringOfLength(drTxHash, 32)) {
      throw new Error(`invalid <WIT_DR_TX_HASH>: ${drTxHash}`)
    } else if (!options?.into) {
      throw new Error("--into <EVM_ADDRESS> must be specified")
    }

    console.info(helpers.colors.lwhite("\n  Fetching result to Wit/Oracle query:"))

    const consumer = await witOracle.getWitOracleConsumerAt(options.into)
    const kermit = await Witnet.KermitClient.fromEnv(options?.kermit)
    console.info(`  > Wit/Kermit provider: ${kermit.url}`)
    const report = await kermit.getDataPushReport(drTxHash, network)

    if (report?.query) {
      console.info(`  > Witnet DRT hash:     ${report.hash}`)
      console.info(`  > Witnet RAD hash:     ${report.query.rad_hash}`)
      console.info(`  > Witnet DRO hash:     ${report.query.dro_hash}`)

      if (report?.result) {
        console.info(`  > Witnet DRT result:   ${JSON.stringify(utils.cbor.decode(utils.fromHexString(report.result.cbor_bytes)))}`)
        console.info(`  > Witnet DRT clock:    ${moment.unix(report.result.timestamp).fromNow()}`)

        if (!report.result.finalized) {
          const user = await prompt([{
            message: "> The Wit/Oracle query is not yet finalized. Proceed anyway ?",
            name: "continue",
            type: "confirm",
            default: false,
          }])
          if (!user.continue) {
            process.exit(0)
          }
        }

        console.info(`\n  ${helpers.colors.lwhite("WitOracleConsumer")}:   ${helpers.colors.lblue(options.into)}`)
        const message = utils.abiEncodeDataPushReportMessage(report)
        const digest = utils.abiEncodeDataPushReportDigest(report)
        helpers.traceData("  > Push data report:  ", message.slice(2), 64, "\x1b[90m")
        console.info(`  > Push data digest:  ${digest.slice(2)}`)
        console.info(`  > Push data proof:   ${report.evm_proof.slice(2)}`)

        await consumer.pushDataReport(report, {
          confirmations: options?.confirmations || 1,
          gasLimit: options?.gasLimit,
          gasPrice: options?.gasPrice,
          onDataPushReportTransaction: (txHash) => {
            process.stdout.write(`  > Pushing report  => ${helpers.colors.gray(txHash)} ... `)
          },
        }).catch(err => {
          process.stdout.write(`${helpers.colors.mred("FAIL")}\n`)
          console.error(err)
        })
        process.stdout.write(`${helpers.colors.lwhite("OK")}\n`)
      } else {
        console.info("  Skipped: the Wit/Oracle query exists but has not yet been solved.")
      }
    } else {
      console.info("  Skipped: the Wit/Oracle query does not exist.")
    }
  }

  // determine current block number
  const blockNumber = await provider.getBlockNumber()

  // determine fromBlock
  let fromBlock
  if (since === undefined || since < 0) {
    fromBlock = BigInt(blockNumber) + BigInt(since ?? DEFAULT_SINCE)
  } else {
    fromBlock = BigInt(since ?? 0n)
  }

  // fetch events since specified block
  let logs = (await witOracle.filterWitOracleReportEvents({
    fromBlock,
    where: {
      evmOrigin: options?.signer,
      evmConsumer: options["filter-consumer"],
      queryRadHash: options["filter-radHash"],
    },
  }))

  // count logs before last filter
  const totalLogs = logs.length

  // apply limit/offset filter
  logs = (!since || BigInt(since) < 0n
    ? logs.slice(offset || 0).slice(0, limit || DEFAULT_LIMIT) // oldest first
    : logs.reverse().slice(offset || 0).slice(0, limit || DEFAULT_LIMIT) // latest first
  )

  // compute tx cost for each record
  logs = await helpers.prompter(
    Promise.all(
      logs.map(async log => {
        const receipt = await provider.getTransactionReceipt(log.evmTransactionHash)
        const transaction = await provider.getTransaction(log.evmTransactionHash)
        const evmTransactionCost = transaction.value + receipt.gasPrice * receipt.gasUsed
        return {
          ...log,
          evmTransactionCost,
        }
      })
    )
  )

  if (logs.length > 0) {
    if (!options["trace-back"]) {
      helpers.traceTable(
        logs.map(log => [
          log.evmBlockNumber,
          `${log?.queryRadHash?.slice(2).slice(0, 6)}..${log?.queryRadHash.slice(-5)}`,
          `${log.queryParams.witnesses}`,
          `${Witnet.Coins.fromPedros(BigInt(log.queryParams.unitaryReward) * (3n + log.queryParams.witnesses)).toString(2)}`,
          `${log.evmOrigin.slice(0, 8)}..${log.evmOrigin.slice(-4)}`,
          `${log?.evmConsumer.slice(0, 8)}..${log?.evmConsumer.slice(-4)}`,
          Number(Number(log?.evmTransactionCost || 0n) / 10 ** 18).toFixed(7),
          parse ? utils.cbor.decode(utils.fromHexString(log?.resultCborBytes)) : log?.resultCborBytes,
        ]),
        {
          colors: [
            helpers.colors.white,
            helpers.colors.mgreen,
            helpers.colors.green,
            helpers.colors.green,
            helpers.colors.mblue,
            helpers.colors.mblue,
            helpers.colors.gray,
            parse ? helpers.colors.mcyan : helpers.colors.cyan,
          ],
          headlines: [
            "EVM BLOCK:",
            ":radon request",
            "witnesses",
            "witnet fees",
            "EVM PUSHER",
            "EVM CONSUMER",
            `$${helpers.colors.lwhite(symbol)} COST`,
            parse ? "REPORTED DATA" : ":REPORTED CBOR BYTES",
          ],
          humanizers: [helpers.commas],
        }
      )
    } else {
      logs = await helpers.prompter(
        Promise.all(logs.map(async log => {
          const ethBlock = await witOracle.provider.getBlock(log.evmBlockNumber)
          return {
            ...log,
            ethBlockTimestamp: ethBlock.timestamp,
          }
        })).catch(err => console.error(err))
      )
      helpers.traceTable(
        logs.map(log => [
          log.evmBlockNumber,
          log.witDrTxHash.slice(2),
          moment.duration(moment.unix(log.ethBlockTimestamp).diff(moment.unix(log.resultTimestamp))).humanize(),
          log.evmTransactionHash,
        ]),
        {
          colors: [
            helpers.colors.white,
            helpers.colors.mmagenta,
            helpers.colors.magenta,
            helpers.colors.gray,
          ],
          headlines: [
            "EVM BLOCK:",
            `DATA WITNESSING ACT ON ${helpers.colors.lwhite(`WITNET ${utils.isEvmNetworkMainnet(network) ? "MAINNET" : "TESTNET"}`)}`,
            "T.T.R.",
            "EVM DATA REPORTING TRANSACTION HASH",
          ],
          humanizers: [helpers.commas,,,,,,],
        }
      )
    }
    console.info(`^ Listed ${logs.length} out of ${totalLogs} pushed data reports${
      fromBlock ? ` since block #${helpers.commas(fromBlock)}.` : ` up until current block #${helpers.colors.lwhite(helpers.commas(blockNumber))}.`
    }`)
  } else {
    console.info(`^ No data reports pushed${fromBlock ? ` since block #${helpers.colors.lwhite(helpers.commas(fromBlock))}.` : "."}`)
  }
}
