const helpers = require("../helpers.cjs")
const ethers = require("ethers")
const moment = require("moment")
const prompt = require("inquirer").createPromptModule()

const { utils, WitOracle } = require("../../../dist/src")
const { colors, DEFAULT_LIMIT, DEFAULT_SINCE } = helpers

module.exports = async function (options = {}, args = []) {
  [args] = helpers.deleteExtraFlags(args)

  const { limit, offset, since, clone } = options

  const witOracle = await WitOracle.fromJsonRpcUrl(
    `http://127.0.0.1:${options?.port || 8545}`,
    options?.signer,
  )

  const { network, provider } = witOracle
  helpers.traceHeader(`${network.toUpperCase()}`, helpers.colors.lcyan)
  const framework = await helpers.prompter(utils.fetchWitOracleFramework(provider))
  let target = args[0]
  let chosen = false
  if (!target) {
    const artifacts = Object.entries(framework).filter(([key]) => key.startsWith("WitRandomness"))
    if (artifacts.length === 1) {
      target = artifacts[0][1].address
    } else {
      const selection = await prompt([{
        choices: artifacts.map(([key, artifact]) => artifact.address),
        message: "Randomness contract:",
        name: "target",
        type: "rawlist",
      }])
      target = selection.target
      chosen = true
    }
  }
  const randomizer = await witOracle.getWitRandomnessAt(target)
  const symbol = utils.getEvmNetworkSymbol(network)

  const [artifact, version, base, consumer ] = await Promise.all([
    await randomizer.getEvmImplClass(),
    await randomizer.getEvmImplVersion(),
    await randomizer.getEvmBase(),
    await randomizer.getEvmConsumer(),
  ])
  let curator = await randomizer.getEvmCurator()

  const maxWidth = Math.max(20, artifact.length + 2)
  console.info(
    `> ${helpers.colors.lwhite(artifact)
    }:${" ".repeat(maxWidth - artifact.length)
    }${chosen ? "" : helpers.colors.lblue(target) + " "
    }${helpers.colors.blue(`[ ${version} ]`)
    }`
  )
  if (base !== randomizer.address) {
    console.info(`> Master address:      ${colors.blue(base)}`)
    if (randomizer.signer.address !== curator) {
      console.info(`> Curator address:     ${colors.magenta(curator)}`)
    } else {
      console.info(`> Curator address:     ${colors.mmagenta(curator)}`)
    }
  }

  if (clone) {
    console.info()
    await prompt([
      {
        name: "setDefault",
        type: "confirm",
        message: "Do you want the new clone to become your default address?",
        default: true,
      },
      {
        name: "curator",
        type: "list",
        message: "Please, select a new curator address:",
        choices: (await randomizer.provider.listAccounts()).map(signer => signer.address),
      },
    ]).then(async answer => {
      console.info(colors.lyellow(`\n  >>> CLONING THE WIT/RANDOMNESS CONTRACT <<<`))
      console.info(`  > Master address:    ${colors.blue(randomizer.address)}`)
      if (answer.curator === randomizer.signer.address) {
        console.info(`  > Curator address:   ${colors.mmagenta(answer.curator)}`)
      } else {
        console.info(`  > Signer address:    ${colors.yellow(randomizer.signer.address)}`)
        console.info(`  > Curator address:   ${colors.magenta(answer.curator)}`)
      }
      const { logs } = await _invokeAdminTask(randomizer.clone.bind(randomizer), answer.curator)
      if (logs && logs[0]) {
        const cloned = logs[0].address
        console.info(`  > Cloned address: ${colors.mblue(cloned)}`)
        randomizer.attach(cloned)
        if (answer.setDefault) {
          let { addresses } = helpers.readWitnetJsonFiles("addresses")
          if (!addresses[network]) addresses[network] = {}
          if (!addresses[network].apps) addresses[network].apps = {}
          addresses[network].apps[artifact] = cloned
          helpers.saveWitnetJsonFiles({ addresses })
        }

      } else {
        console.error(colors.mred(`  Error: no Cloned event was emitted.`))
        process.exit(0)
      }
      curator = answer.curator
    })
  } else {
    if (consumer !== "0x0000000000000000000000000000000000000000") {
      console.info(`> Consumer address:    ${colors.cyan(consumer)}`)
    }
  }

  if (options?.randomize) {
    console.info(colors.lyellow(`\n  >>> REQUESTING NEW RANDOMIZE <<<`))
    const receipt = await randomizer.randomize({
      evmConfirmations: options?.confirmations || 1,
      evmGasPrice: options?.gasPrice,
      evmTimeout: options?.timeout,
      onRandomizeTransaction: (txHash) => {
        console.info(`  > EVM signer:${" ".repeat(maxWidth - 10)}${helpers.colors.gray(randomizer.signer.address)}`)
        process.stdout.write(`  > EVM transaction:${" ".repeat(maxWidth - 15)}${helpers.colors.gray(txHash)} ... `)
      },
      onRandomizeTransactionReceipt: () => {
        process.stdout.write(`${helpers.colors.lwhite("OK")}\n`)
      },
    }).catch(err => {
      process.stdout.write(`${helpers.colors.mred("FAIL")}`)
      console.error(err)
      throw err
    })
    if (receipt) {
      console.info(`  > EVM block number:${" ".repeat(maxWidth - 16)}${helpers.colors.lwhite(helpers.commas(receipt?.blockNumber))}`)
      console.info(`  > EVM tx gas price:${" ".repeat(maxWidth - 16)}${helpers.colors.lwhite(helpers.commas(receipt?.gasPrice))} weis`)
      console.info(`  > EVM tx fee:${" ".repeat(maxWidth - 10)}${helpers.colors.lwhite(ethers.formatEther(receipt.fee))} ETH`)
      const value = (await receipt.getTransaction()).value
      console.info(`  > EVM randomize fee:${" ".repeat(maxWidth - 17)}${helpers.colors.lwhite(ethers.formatEther(value))} ETH`)
      console.info(`  > EVM effective gas:${" ".repeat(maxWidth - 17)}${helpers.commas(Math.floor(Number((receipt.fee + value) / receipt.gasPrice)))
        } gas units`)
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
  let logs = await randomizer.filterEvents({ fromBlock })

  // count logs before last filter
  const totalLogs = logs.length

  // apply limit/offset filter
  logs = (!since || BigInt(since) < 0n
    ? logs.slice(offset || 0).slice(0, limit || DEFAULT_LIMIT) // oldest first
    : logs.reverse().slice(offset || 0).slice(0, limit || DEFAULT_LIMIT) // latest first
  )

  // fetch randomize status and evm cost for each log entry
  logs = await helpers.prompter(
    Promise.all(
      logs.map(async log => {
        const block = await provider.getBlock(log.randomizeBlock)
        const receipt = await provider.getTransactionReceipt(log.transactionHash)
        const status = await randomizer.getRandomizeStatus(log.randomizeBlock)
        const transaction = await provider.getTransaction(log.transactionHash)
        let readiness = {}
        try {
          if (status === "Ready") {
            const randomness = options["trace-back"] ? await randomizer.fetchRandomnessAfter(log.randomizeBlock) : undefined
            let { btr, finality, trail, timestamp } = await randomizer.fetchRandomnessAfterProof(log.randomizeBlock)
            if (finality) {
              timestamp = (await provider.getBlock(finality)).timestamp
              btr = finality - log.randomizeBlock
            }
            const ttr = moment.duration(moment.unix(timestamp).diff(moment.unix(Number(block.timestamp)))).humanize()
            readiness = { btr, finality, randomness, trail, ttr }
          }
        } catch { }
        return {
          ...log,
          cost: transaction.value + receipt.gasPrice * receipt.gasUsed,
          gasPrice: receipt.gasPrice,
          origin: transaction.from,
          status,
          ...readiness,
          blockTimestamp: block.timestamp,
        }
      })
    ).catch(err => console.error(err))
  )
  if (logs?.length > 0) {
    if (options["trace-back"]) {
      helpers.traceTable(
        logs.map(log => [
          log.randomizeBlock,
          log.btr,
          log.trail?.slice(2),
          log.randomness,
        ]),
        {
          colors: [
            helpers.colors.white,
            helpers.colors.lwhite,
            helpers.colors.magenta,
            helpers.colors.green,
          ],
          headlines: [
            "EVM BLOCK:",
            "B.T.R.",
            `RANDOMIZE WITNESSING ACT ON ${helpers.colors.lwhite(`WITNET ${utils.isEvmNetworkMainnet(network) ? "MAINNET" : "TESTNET"}`)}`,
            "WITNET-GENERATED RANDOMNESS",
          ],
          humanizers: [helpers.commas, helpers.commas],
        }
      )
    } else {
      helpers.traceTable(
        logs.map(log => [
          log.randomizeBlock,
          moment.unix(log.blockTimestamp),
          log.origin, // `${log.origin?.slice(0, 8)}..${log.origin?.slice(-4)}`,
          (
            Number(log.gasPrice) / 10 ** 9 < 1.0
              ? Number(Number(log.gasPrice) / 10 ** 9).toFixed(6)
              : helpers.commas(Number(Number(log.gasPrice) / 10 ** 9).toFixed(1))
          ) + " gwei",
          Number(Number(log.cost) / 10 ** 18).toFixed(9),
          log.ttr,
          log.status === "Error"
            ? helpers.colors.mred("Error")
            : (log.status === "Ready"
              ? helpers.colors.mgreen("Ready")
              : helpers.colors.yellow(log.status)
            ),

        ]),
        {
          colors: [
            helpers.colors.white,
            helpers.colors.lwhite,
            helpers.colors.mblue,
            helpers.colors.blue,
            helpers.colors.gray, ,
            helpers.colors.magenta,
          ],
          headlines: [
            "EVM BLOCK:",
            "EVM TIMESTAMP",
            ":EVM RANDOMIZER",
            "EVM GAS PRICE",
            `$${helpers.colors.lwhite(symbol)} COST`,
            "T.T.R.",
            ":STATUS",
          ],
          humanizers: [helpers.commas, , , helpers.commas],
        }
      )
    }
    console.info(`^ Listed ${logs.length} out of ${totalLogs} randomness requests${fromBlock ? ` since block #${helpers.commas(fromBlock)}.` : ` up until current block #${helpers.colors.lwhite(helpers.commas(blockNumber))}.`
      }`)
  } else {
    console.info(`^ No randomness requests${fromBlock ? ` since block #${helpers.colors.lwhite(helpers.commas(fromBlock))}.` : "."}`)
  }
}

async function _invokeAdminTask(func, ...params) {
    const receipt = await func(...params, {
        // evmConfirmations: helpers.parseIntFromArgs(process.argv, `--confirmations`) || 2,
        onTransaction: (txHash) => {
            process.stdout.write(`  - EVM transaction:   ${helpers.colors.gray(txHash)} ... `)
        },
        onTransactionReceipt: () => {
            process.stdout.write(`${helpers.colors.lwhite("OK")}\n`)
        },
    }).catch(err => {
        process.stdout.write(`${helpers.colors.mred("FAIL:\n")}`)
        console.error(err)
        process.exit(1)
    })
    if (receipt) {
        console.info(`  - EVM block number:  ${helpers.colors.lwhite(helpers.commas(receipt?.blockNumber))}`)
        console.info(`  - EVM tx gas price:  ${helpers.colors.lwhite(helpers.commas(receipt?.gasPrice))} weis`)
        console.info(`  - EVM tx fee:        ${helpers.colors.lwhite(ethers.formatEther(receipt.fee))} ETH`)
        const value = (await receipt.getTransaction()).value
        console.info(`  - EVM randomize fee: ${helpers.colors.lwhite(ethers.formatEther(value))} ETH`)
        console.info(`  - EVM effective gas: ${helpers.commas(Math.floor(Number((receipt.fee + value) / receipt.gasPrice)))} gas units`)
    }
    return receipt
}
