const addresses = require("../migrations/witnet.addresses.json")
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
        WitnetPriceFeeds: merged?.WitnetPriceFeeds,
        WitnetRandomness: merged?.WitnetRandomness,
        WitnetRequestBoard: merged?.WitnetRequestBoard,        
      }
    } else {
      return {}
    }
  },
  supportedEcosystems: () => {
    let ecosystems = []
    supportedNetworks().forEach(network => {
      const [ecosystem,] = utils.getRealmNetworkFromString(network)
      if (!ecosystems.includes(ecosystem)) {
        ecosystems.push(ecosystem)
      }
    });
    return ecosystems
  },
  supportedNetworks,
  artifacts: {
    WitnetBytecodes: require("../artifacts/contracts/WitnetBytecodes.sol/WitnetBytecodes.json"),
    WitnetPriceFeeds: require("../artifacts//contracts/apps/WitnetPriceFeeds.sol/WitnetPriceFeeds.json"),
    WitnetRandomness: require("../artifacts//contracts/apps/WitnetRandomness.sol/WitnetRandomness.json"),
    WitnetRequest: require("../artifacts//contracts/WitnetRequest.sol/WitnetRequest.json"),
    WitnetRequestBoard: require("../artifacts//contracts/WitnetRequestBoard.sol/WitnetRequestBoard.json"),
    WitnetRequestFactory: require("../artifacts//contracts/WitnetRequestFactory.sol/WitnetRequestFactory.json"),
    WitnetRequestTemplate: require("../artifacts//contracts/WitnetRequestTemplate.sol/WitnetRequestTemplate.json"),
    WitnetUpgradableBase: require("../artifacts//contracts/core/WitnetUpgradableBase.sol/WitnetUpgradableBase.json"),
  },
  settings: require("../settings"),
  utils,
}

function supportedNetworks() {
  return Object
    .entries(addresses)
    .filter(value => value[0].indexOf(":") > -1)
    .map(value => value[0])
    .sort()
}
