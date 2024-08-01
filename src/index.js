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
        WitnetOracle: merged?.WitnetOracle,
        WitnetPriceFeeds: merged?.WitnetPriceFeeds,
        WitnetRandomnessV2: merged?.WitnetRandomnessV2,
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
    WitnetOracle: require("../artifacts/contracts/WitnetOracle.sol/WitnetOracle.json"),
    WitnetPriceFeeds: require("../artifacts/contracts/WitnetPriceFeeds.sol/WitnetPriceFeeds.json"),
    WitnetPriceRouteSolver: require("../artifacts/contracts/interfaces/IWitnetPriceSolver.sol/IWitnetPriceSolver.json"),
    WitnetRandomness: require("../artifacts/contracts/WitnetRandomness.sol/WitnetRandomness.json"),
    WitnetRequest: require("../artifacts/contracts/WitnetRequest.sol/WitnetRequest.json"),
    WitnetRadonRegistry: require("../artifacts/contracts/WitnetRadonRegistry.sol/WitnetRadonRegistry.json"),
    WitnetRequestFactory: require("../artifacts/contracts/WitnetRequestFactory.sol/WitnetRequestFactory.json"),
    WitnetRequestTemplate: require("../artifacts/contracts/WitnetRequestTemplate.sol/WitnetRequestTemplate.json"),
    WitnetUpgradableBase: require("../artifacts/contracts/core/WitnetUpgradableBase.sol/WitnetUpgradableBase.json"),
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
