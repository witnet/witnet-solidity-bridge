const utils = require("../../scripts/utils")

const WitnetErrorsLib = artifacts.require("WitnetErrorsLib")
const WitnetEncodingLib = artifacts.require("WitnetEncodingLib")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  var addresses = require("../witnet.addresses")
  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  var lib
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetErrorsLib)) {
    await deployer.deploy(WitnetErrorsLib, { from })
    lib = await WitnetErrorsLib.deployed()
    addresses[ecosystem][network].WitnetErrorsLib = lib.address
  } else {
    lib = await WitnetErrorsLib.at(addresses[ecosystem][network]?.WitnetErrorsLib)
    WitnetErrorsLib.address = lib.address
    utils.traceHeader("Skipping 'WitnetErrorsLib'")
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
    lib = await WitnetEncodingLib.at(addresses[ecosystem][network]?.WitnetEncodingLib)
    WitnetEncodingLib.address = lib.address
    utils.traceHeader("Skipping 'WitnetEncodingLib'")
    console.info("  ", "> library address:", lib.address)
    console.info()
  }
  if (!isDryRun) {
    utils.saveAddresses(addresses)
  }
}