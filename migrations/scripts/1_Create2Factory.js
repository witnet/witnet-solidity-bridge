const addresses = require("../witnet.addresses")
const utils = require("../../scripts/utils")

const Create2Factory = artifacts.require("Create2Factory")
const WitnetProxy = artifacts.require("WitnetProxy")

module.exports = async function (deployer, network, [,,,,,, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  var factory
  if (utils.isNullAddress(addresses[ecosystem][network]?.Create2Factory)) {
    await deployer.deploy(Create2Factory, { from })    
    factory = await Create2Factory.deployed()
    addresses[ecosystem][network].Create2Factory = factory.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    factory = await Create2Factory.at(addresses[ecosystem][network].Create2Factory)
    Create2Factory.address = factory.address
    utils.traceHeader(`Skipping 'Create2Factory'`)
    console.info("   > Contract address:", factory.address)
    console.info()
  }
  if (addresses[ecosystem][network]?.WitnetProxy === "") {
    await deployer.deploy(WitnetProxy, { from })
    addresses[ecosystem][network].WitnetProxy = WitnetProxy.address
  }
  if (!isDryRun) {
    utils.saveAddresses(addresses)
  }
}