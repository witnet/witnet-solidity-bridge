const utils = require("../../src/utils")

const WitnetDeployer = artifacts.require("WitnetDeployer")

module.exports = async function (deployer, network, [, from,, master]) {  
  const addresses = await utils.readAddresses(network)
  let factory
  if (utils.isNullAddress(addresses?.WitnetDeployer)) {
    await deployer.deploy(WitnetDeployer, { from: master })
    factory = await WitnetDeployer.deployed()
    addresses.WitnetDeployer = factory.address
  } else {
    factory = await WitnetDeployer.at(addresses.WitnetDeployer)
    WitnetDeployer.address = factory.address
    utils.traceHeader("Skipped 'WitnetDeployer'")
    console.info("   > Contract address:", factory.address)
    console.info()
  }

  if (!utils.isDryRun(network)) {
    await utils.saveAddresses(network, addresses)
  }
}
