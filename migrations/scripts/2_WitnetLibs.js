const utils = require("../../scripts/utils")

const WitnetLib = artifacts.require("WitnetLib")
const WitnetEncodingLib = artifacts.require("WitnetEncodingLib")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  var addresses = require("../witnet.addresses")
  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  var lib
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetLib)) {
    await deployer.deploy(WitnetLib, { from })
    lib = await WitnetLib.deployed()
    addresses[ecosystem][network].WitnetLib = lib.address
  } else {
    lib = await WitnetLib.at(addresses[ecosystem][network]?.WitnetLib)
    WitnetLib.address = lib.address
    utils.traceHeader("Skipping 'WitnetLib'")
    console.info("  ", "> library address:", lib.address)
    console.info()
  }
  if (!isDryRun) {
    utils.saveAddresses(addresses)
  }
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetEncodingLib)) {
    await deployer.deploy(WitnetEncodingLib, { from })
    lib = await WitnetEncodingLib.deployed()
    addresses[ecosystem][network].WitnetEncodingLib = lib.address
  } else {
    lib = await WitnetLib.at(addresses[ecosystem][network]?.WitnetEncodingLib)
    WitnetEncodingLib.address = lib.address
    utils.traceHeader("Skipping 'WitnetEncodingLib'")
    console.info("  ", "> library address:", lib.address)
    console.info()
  }
  if (!isDryRun) {
    utils.saveAddresses(addresses)
  }
}