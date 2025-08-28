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
    WitOracleConsumer: require("../artifacts/contracts/mockups/WitOracleConsumer.sol/WitOracleConsumer.json").abi,
    WitOracleRadonRegistry: require("../artifacts/contracts/WitOracleRadonRegistry.sol/WitOracleRadonRegistry.json").abi,
    WitOracleRadonRequestFactory: require("../artifacts/contracts/WitOracleRadonRequestFactory.sol/WitOracleRadonRequestFactory.json").abi,
    IWitOracleRadonRequestModal: require("../artifacts/contracts/interfaces/IWitOracleRadonRequestModal.sol/IWitOracleRadonRequestModal.json").abi,
    IWitOracleRadonRequestTemplate: require("../artifacts/contracts/interfaces/IWitOracleRadonRequestTemplate.sol/IWitOracleRadonRequestTemplate.json").abi,
    WitPriceFeeds: require("../artifacts/contracts/WitPriceFeeds.sol/WitPriceFeeds.json").abi,
    WitPriceFeedsLegacy: require("../artifacts/contracts/WitPriceFeedsLegacy.sol/WitPriceFeedsLegacy.json").abi,
    WitRandomness: require("../artifacts/contracts/WitRandomness.sol/WitRandomness.json").abi,
    WitRandomnessV2: require("../migrations/frosts/apps/WitRandomnessV2.json").abi,
    WitnetUpgradableBase: require("../artifacts/contracts/core/WitnetUpgradableBase.sol/WitnetUpgradableBase.json").abi,
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
          symbol: networks[network]?.symbol || "ETH",
          verified: networks[network]?.verify?.explorerUrl
        }
      ])
  );
}
