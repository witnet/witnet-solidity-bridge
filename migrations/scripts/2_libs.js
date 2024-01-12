const { merge } = require("lodash")

const settings = require("../witnet.settings")
const utils = require("../../scripts/utils")

const WitnetDeployer = artifacts.require("WitnetDeployer")

module.exports = async function (_, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  const addresses = require("../witnet.addresses")
  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  const targets = merge(
    settings.artifacts.default,
    settings.artifacts[ecosystem],
    settings.artifacts[network]
  )
  const libs = [
    targets.WitnetErrorsLib,
    targets.WitnetEncodingLib,
    targets.WitnetPriceFeedsLib,
  ]

  const deployer = await WitnetDeployer.deployed()
  for (index in libs) {
    const key = libs[index]
    const artifact = artifacts.require(key)
    if (utils.isNullAddress(addresses[ecosystem][network][key])) {
      utils.traceHeader(`Deploying '${key}'...`)
      const libInitCode = artifact.toJSON().bytecode
      const libAddr = await deployer.determineAddr.call(libInitCode, "0x0", { from })
      console.info("  ", "> account:          ", from)
      console.info("  ", "> balance:          ", web3.utils.fromWei(await web3.eth.getBalance(from), "ether"), "ETH")
      const tx = await deployer.deploy(libInitCode, "0x0", { from })
      utils.traceTx(tx)
      if ((await web3.eth.getCode(libAddr)).length > 3) {
        addresses[ecosystem][network][key] = libAddr
      } else {
        console.info(`Error: Library was not deployed on expected address: ${libAddr}`)
        process.exit(1)
      }
    } else {
      utils.traceHeader(`Skipped '${key}'`)
    }
    artifact.address = addresses[ecosystem][network][key]
    console.info("  ", "> library address:  ", artifact.address)
    console.info("  ", "> library codehash: ", web3.utils.soliditySha3(await web3.eth.getCode(artifact.address)))
    console.info()
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  }
}
