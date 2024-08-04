const settings = require("../../settings")
const utils = require("../../src/utils")

const WitnetDeployer = artifacts.require("WitnetDeployer")

module.exports = async function (_, network, [, from]) {
  const addresses = await utils.readJsonFromFile("./migrations/addresses.json")
  if (!addresses[network]) addresses[network] = {}

  const targets = settings.getArtifacts(network)
  const libs = [
    targets.WitPriceFeedsLib,
    targets.WitOracleDataLib,
    targets.WitOracleRadonEncodingLib,
    targets.WitOracleResultErrorsLib,
  ]

  const selection = utils.getWitnetArtifactsFromArgs()

  const deployer = await WitnetDeployer.deployed()
  for (const index in libs) {
    const key = libs[index]
    const artifact = artifacts.require(key)
    if (
      utils.isNullAddress(addresses[network][key]) ||
      (await web3.eth.getCode(addresses[network][key])).length < 3 ||
      selection.includes(key)
    ) {
      utils.traceHeader(`Deploying '${key}'...`)
      const libInitCode = artifact.toJSON().bytecode
      const libAddr = await deployer.determineAddr.call(libInitCode, "0x0", { from })
      console.info("  ", "> account:          ", from)
      console.info("  ", "> balance:          ", web3.utils.fromWei(await web3.eth.getBalance(from), "ether"), "ETH")
      const tx = await deployer.deploy(libInitCode, "0x0", { from })
      utils.traceTx(tx)
      if ((await web3.eth.getCode(libAddr)).length > 3) {
        addresses[network][key] = libAddr
      } else {
        console.info(`Error: Library was not deployed on expected address: ${libAddr}`)
        process.exit(1)
      }
      if (!utils.isDryRun(network)) {
        await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
      }
    } else {
      utils.traceHeader(`Skipped '${key}'`)
    }
    artifact.address = addresses[network][key]
    console.info("  ", "> library address:  ", artifact.address)
    console.info("  ", "> library codehash: ", web3.utils.soliditySha3(await web3.eth.getCode(artifact.address)))
    console.info()
  }
}
