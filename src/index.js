const addresses = require("../migrations/addresses.json")
const merge = require("lodash.merge")
const utils = require("./utils")
module.exports = {
  getAddresses: (network) => {
    const [eco, net] = utils.getRealmNetworkFromString(network)
    if (addresses[net]) {
      const merged = merge(
        addresses.default,
        addresses[eco],
        addresses[net],
      )
      return {
        WitOracle: merged?.WitOracle,
        WitPriceFeeds: merged?.WitPriceFeeds,
        WitRandomnessV21: merged?.WitRandomnessV21,
      }
    } else {
      return {}
    }
  },
  supportedEcosystems: () => {
    const ecosystems = []
    supportedNetworks().forEach(network => {
      const [ecosystem] = utils.getRealmNetworkFromString(network)
      if (!ecosystems.includes(ecosystem)) {
        ecosystems.push(ecosystem)
      }
    })
    return ecosystems
  },
  supportedNetworks,
  artifacts: {
    WitOracle: require("../artifacts/contracts/WitOracle.sol/WitOracle.json"),
    WitOracleRequest: require("../artifacts/contracts/WitOracleRequest.sol/WitOracleRequest.json"),
    WitOracleRadonRegistry: require("../artifacts/contracts/WitOracleRadonRegistry.sol/WitOracleRadonRegistry.json"),
    WitOracleRequestFactory: require("../artifacts/contracts/WitOracleRequestFactory.sol/WitOracleRequestFactory.json"),
    WitOracleRequestTemplate: require("../artifacts/contracts/WitOracleRequestTemplate.sol/WitOracleRequestTemplate.json"),
    WitPriceFeeds: require("../artifacts/contracts/WitPriceFeeds.sol/WitPriceFeeds.json"),
    WitRandomness: require("../artifacts/contracts/WitRandomness.sol/WitRandomness.json"),
    WitnetUpgradableBase: require("../artifacts/contracts/core/WitnetUpgradableBase.sol/WitnetUpgradableBase.json"),
    IWitPriceFeedsSolver: require("../artifacts/contracts/interfaces/IWitPriceFeedsSolver.sol/IWitPriceFeedsSolver.json"),
  },
  settings: require("../settings"),
  utils,
}

function supportedNetworks (ecosystem) {
  return Object
    .entries(addresses)
    .filter(value => value[0].indexOf(":") > -1 && (!ecosystem || value[0].startsWith(ecosystem)))
    .map(value => value[0])
    .sort()
}
