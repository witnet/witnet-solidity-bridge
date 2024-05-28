const settings = require("../../settings")
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
    const WitnetDeployerImpl = artifacts.require(settings.getArtifacts(network).WitnetDeployer)
    await deployer.deploy(WitnetDeployerImpl, { 
      from: settings.getSpecs(network)?.WitnetDeployer?.from || web3.utils.toChecksumAddress(master)
    })
    const factory = await WitnetDeployerImpl.deployed()
    if (factory.address !== addresses?.default?.WitnetDeployer) {
      addresses[network].WitnetDeployer = factory.address
      if (!utils.isDryRun(network)) {
        await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
      }
    }
    WitnetDeployer.address = factory.address
  } else {
    const factory = await WitnetDeployer.at(factoryAddr)
    WitnetDeployer.address = factory.address
    utils.traceHeader("Skipped 'WitnetDeployer'")
    console.info("   > Contract address:", factory.address)
    console.info()
  }

  const proxyAddr = addresses[network]?.WitnetProxy || addresses?.default?.WitnetProxy || ""
  if (
    utils.isNullAddress(proxyAddr) ||
      (await web3.eth.getCode(proxyAddr)).length < 3
  ) {
    await deployer.deploy(WitnetProxy, { 
      from: settings.getSpecs(network)?.WitnetDeployer?.from || master 
    })
    if (WitnetProxy.address !== addresses?.default?.WitnetProxy) {
      addresses[network].WitnetProxy = WitnetProxy.address
      if (!utils.isDryRun(network)) {
        await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
      }
    }
  }
}
