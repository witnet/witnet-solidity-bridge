const addresses = require("../witnet.addresses")
const utils = require("../../scripts/utils")

const WitnetDeployer = artifacts.require("WitnetDeployer")

module.exports = async function (deployer, network, [, from,, master]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  let factory
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetDeployer)) {
    await deployer.deploy(WitnetDeployer, { from: master })
    factory = await WitnetDeployer.deployed()
    addresses[ecosystem][network].WitnetDeployer = factory.address
  } else {
    factory = await WitnetDeployer.at(addresses[ecosystem][network].WitnetDeployer)
    WitnetDeployer.address = factory.address
    utils.traceHeader("Skipped 'WitnetDeployer'")
    console.info("   > Contract address:", factory.address)
    console.info()
  }

  if (!isDryRun) {
    utils.saveAddresses(addresses)
  }
}
