const utils = require("../../src/utils")

const WitnetDeployer = artifacts.require("WitnetDeployer")

module.exports = async function (deployer, network, [,,, master]) {
  const addresses = await utils.readAddresses()
  if (!addresses[network]) addresses[network] = {};

  const factoryAddr = addresses[network]?.WitnetDeployer || addresses?.default?.WitnetDeployer || ""
  if (
    utils.isNullAddress(factoryAddr)
      || (await web3.eth.getCode(factoryAddr)).length < 3
  ) {
    await deployer.deploy(WitnetDeployer, { from: master })
    const factory = await WitnetDeployer.deployed()
    addresses[network].WitnetDeployer = factory.address
    if (!utils.isDryRun(network)) {
      await utils.saveAddresses(addresses)
    }
  } else {
    const factory = await WitnetDeployer.at(factoryAddr)
    WitnetDeployer.address = factory.address
    utils.traceHeader("Skipped 'WitnetDeployer'")
    console.info("   > Contract address:", factory.address)
    console.info()
  }
}
