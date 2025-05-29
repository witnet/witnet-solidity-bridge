const addresses = require("../migrations/addresses.json")
const constructorArgs = require("../migrations/constructorArgs.json")
const merge = require("lodash.merge")
const utils = require("./utils")
module.exports = {
  getNetworkAddresses: (network) => {
    let res = addresses?.default
    utils.getNetworkTagsFromString(network).forEach(net => {
      res = merge(res, addresses[net])
    })
    return res
  },
  getNetworkConstructorArgs: (network) => {
    let res = {}
    utils.getNetworkTagsFromString(network).forEach(net => {
      res = merge(res, constructorArgs[net])
    })
    return res
  },
  supportedEcosystems: () => {
    const ecosystems = []
    Object.keys(supportedNetworks()).forEach(network => {
      const [ecosystem] = utils.getRealmNetworkFromString(network)
      if (!ecosystems.includes(ecosystem)) {
        ecosystems.push(ecosystem)
      }
    })
    return ecosystems
  },
  supportedNetworks,
  supportsNetwork,
  ABIs: {
    WitOracle: require("../artifacts/contracts/WitOracle.sol/WitOracle.json").abi,
    WitOracleRequest: require("../artifacts/contracts/WitOracleRequest.sol/WitOracleRequest.json").abi,
    WitOracleRadonRegistry: require("../artifacts/contracts/WitOracleRadonRegistry.sol/WitOracleRadonRegistry.json").abi,
    WitOracleRequestFactory: require("../artifacts/contracts/WitOracleRequestFactory.sol/WitOracleRequestFactory.json").abi,
    WitOracleRequestTemplate: require("../artifacts/contracts/WitOracleRequestTemplate.sol/WitOracleRequestTemplate.json").abi,
    WitPriceFeeds: require("../artifacts/contracts/WitPriceFeeds.sol/WitPriceFeeds.json").abi,
    WitRandomness: require("../artifacts/contracts/WitRandomness.sol/WitRandomness.json").abi,
    WitnetUpgradableBase: require("../artifacts/contracts/core/WitnetUpgradableBase.sol/WitnetUpgradableBase.json").abi,
    IWitPriceFeedsLegacySolver: require("../artifacts/contracts/interfaces/IWitPriceFeedsLegacySolver.sol/IWitPriceFeedsLegacySolver.json").abi,
  },
  settings: require("../settings"),
  utils,
}

function supportsNetwork(network) {
  return network && Object.keys(constructorArgs).includes(network.toLowerCase())
}

function supportedNetworks (ecosystem) {
  const networks = require('../settings/networks')
  return Object.fromEntries(
    Object.keys(constructorArgs)
      .sort()
      .filter(network => network.indexOf(":") >= 0 && (!ecosystem || network.startsWith(ecosystem.toLowerCase())))
      .map(network => [
        network,
        {
          mainnet: networks[network]?.mainnet || false,
          network_id: networks[network].network_id,
          port: networks[network].port,
          verified: networks[network]?.verify?.explorerUrl
        }
      ])
  );
}
