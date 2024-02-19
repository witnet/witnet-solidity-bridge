const utils = require("../../src/utils")

const WitnetDeployer = artifacts.require("WitnetDeployer")
const WitnetProxy = artifacts.require("WitnetProxy")

module.exports = async function (deployer, network, [,,, master]) {
  const addresses = await utils.readJsonFromFile("./migrations/addresses.json")
  if (!addresses[network]) addresses[network] = {}

  const factoryAddr = addresses[network]?.WitnetDeployer || addresses?.default?.WitnetDeployer || ""
  if (
    utils.isNullAddress(factoryAddr) ||
      (await web3.eth.getCode(factoryAddr)).length < 3
  ) {
    await deployer.deploy(WitnetDeployer, { from: master })
    const factory = await WitnetDeployer.deployed()
    addresses[network].WitnetDeployer = factory.address
    if (!utils.isDryRun(network)) {
      await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
    }
  } else {
    const factory = await WitnetDeployer.at(factoryAddr)
    WitnetDeployer.address = factory.address
    utils.traceHeader("Skipped 'WitnetDeployer'")
    console.info("   > Contract address:", factory.address)
    console.info()
  }

  if (utils.isNullAddress(addresses[network]?.WitnetProxy)) {
    await deployer.deploy(WitnetProxy, { from: master })
    addresses[network].WitnetProxy = WitnetProxy.address
    if (!utils.isDryRun(network)) {
      await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
    }
  }
}
