const artifacts = require("./artifacts")
const merge = require("lodash.merge")
const networks = require("./networks")
const specs = require("./specs")
const solidity = require("./solidity")
const utils = require("../src/utils")

module.exports = {
  getArtifacts: (network) => {
    const [eco, net] = utils.getRealmNetworkFromArgs(network)
    return merge(
      artifacts.default,
      artifacts[eco],
      artifacts[net]
    )
  },
  getCompilers: (network) => {
    const [eco, net] = utils.getRealmNetworkFromArgs(network)
    return merge(
      solidity.default,
      solidity[eco],
      solidity[net],
    )
  },
  getNetworks: () => {
    return Object.fromEntries(Object.entries(networks)
      .filter(entry => entry[0].indexOf(":") > -1)
      .map(entry => {
        const [ecosystem, network] = utils.getRealmNetworkFromString(entry[0])
        return [
          network.toLowerCase(), merge(
            { ...networks.default },
            networks[ecosystem],
            networks[entry[0]]
          ),
        ]
      })
    )
  },
  getSpecs: (network) => {
    const [eco, net] = utils.getRealmNetworkFromArgs(network)
    return merge(
      specs.default,
      specs[eco],
      specs[net]
    )
  },
  artifacts,
  solidity,
  specs,
}
