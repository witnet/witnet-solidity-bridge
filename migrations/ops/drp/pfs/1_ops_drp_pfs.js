require("dotenv").config()

const addresses = require("../../../addresses")
const cbor = require("cbor")
const exec = require("child_process").execSync
const readline = require("readline")
const utils = require("../../../../src/utils")

const IWitnetOracleReporter = artifacts.require("IWitOracleQueriableTrustableReporter")
const IWitPriceFeedsLegacy = artifacts.require("IWitPriceFeedsLegacy")
const WitnetPriceFeeds = artifacts.require("WitPriceFeeds")
const WitnetOracle = artifacts.require("WitOracle")

module.exports = async function (_deployer, _network, [,, from]) {
  const pfs = await WitnetPriceFeeds.deployed()
  const pfs_legacy = await IWitPriceFeedsLegacy.at(pfs.address)
  const supported = await pfs_legacy.supportedFeeds.call()
  let prices
  try {
    prices = await pfs_legacy.latestPrices.call(supported[0])
  } catch {
    prices = "?".repeat(supported[0].length).split("?")
  }
  console.log("\t\t\tID4\t\tRAD hash\t\t\t\t\t\t\t\tDeviation\tPending")
  const batch = []
  const feeds = []
  for (let ix = 0; ix < supported[0].length; ix++) {
    const id4 = supported[0][ix]
    const caption = supported[1][ix]
    const latestStatus = await pfs_legacy.latestUpdateResponseStatus.call(id4)
    const latestQueryId = await pfs_legacy.latestUpdateQueryId.call(id4)
    const decimals = parseInt((await pfs_legacy.lookupDecimals.call(id4)).toString())
    const radhash = supported[2][ix]
    if (radhash.endsWith("000000000000000000000000")) continue
    const lastPriceUpdate = prices[ix]
    const lastPrice = parseInt(lastPriceUpdate.value)
    const bytecode = await pfs_legacy.lookupWitnetBytecode.call(id4)
    const dryrun = JSON.parse(exec(`npx witnet radon dry-run ${bytecode.slice(2)} --json`).toString())
    const currentPrice = parseInt(dryrun?.RadonInteger)
    const cborBytes = "0x" + cbor.encode(parseInt(currentPrice)).toString("hex")
    const deviation = ((100 * (currentPrice - lastPrice)) / lastPrice)
    const pending = parseInt(latestStatus.toString()) == 1
    const queryId = pending ? latestQueryId.toString() : 0
    feeds.push({
      id4,
      caption,
      decimals,
      radhash,
      bytecode,
      drTxHash: lastPriceUpdate.drTxHash,
      elapsedSecs: Math.round(Date.now() / 1000) - parseInt(lastPriceUpdate.timestamp),
      lastPrice,
      currentPrice,
      deviation,
      pending,
      queryId,
      cborBytes,
    })
    process.stdout.write(`${caption}${caption.length > 15 ? "\t" : "\t\t"}${id4}\t`)
    process.stdout.write(`${radhash.slice(2)}\t`)
    process.stdout.write(`${Math.round(deviation * 100) / 100}%\t\t`)
    process.stdout.write(`${pending}\n`)
    if (pending && currentPrice === currentPrice) {
      batch.push([
        parseInt(queryId),
        Math.floor(Date.now() / 1000) - 90,
        "0x" + utils.padLeft("", "0", 64),
        cborBytes,
      ])
    }
  }
  if (batch.length > 0) {
    const answer = (await prompt(`\nForcely update pending feeds (${batch.length})? [y/N] `)).toLowerCase().trim()
    if (["y", "yes"].includes(answer)) {
      const wrb = await IWitnetOracleReporter.at(WitnetOracle.address)
      console.log(batch)
      const tx = await wrb.reportResultBatch(batch, { gas: 4000000, from })
      tx.logs.map(log => console.log(`  => ${log.event}(${log.args[0].toString()}, ${log.args[1]})`))
    }
  }
  console.log()
}

async function prompt (text) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  })
  let answer
  await new Promise((resolve) => {
    rl.question(
      text,
      function (input) {
        answer = input
        rl.close()
      })
    rl.on("close", function () {
      resolve()
    })
  })
  return answer
}
