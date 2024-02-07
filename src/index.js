const addresses = require("../migrations/witnet.addresses.json")
const merge = require("lodash.merge")
const utils = require("./utils")
module.exports = {
  getAddresses: (network) => {
    const [eco, net] = utils.getRealmNetworkFromArgs(network)
    if (addresses[net]) {
      return merge(
        addresses.default,
        addresses[eco],
        addresses[net],
      )
    } else {
      return {}
    }
  },
  listNetworks: () => {
    return Object
      .entries(addresses)
      .filter(value => value[0].indexOf(":") > -1)
      .map(value => value[0])
      .sort()
  },
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
