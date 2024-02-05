const addresses = require("./migrations/witnet.addresses.json")
const { merge } = require("lodash")
const utils = require("./utils")
module.exports = {
  getAddresses: (network) => {
    const [eco, net] = utils.getRealmNetworkFromArgs(network)
    return merge(
      addresses.default,
      addresses[eco],
      addresses[net],
    )
  },
  getNetworks: () => {
    return Object
      .entries(addresses)
      .filter(value => value[0].indexOf(":") > -1)
      .map(value => value[0])
      .sort()
  },
  artifacts: require("../artifacts"),
  settings: require("../settings"),
  utils,
}
