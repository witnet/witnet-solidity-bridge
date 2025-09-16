const merge = require("lodash.merge")

const artifacts = require("./artifacts.cjs")
const networks = require("./networks.cjs")
const specs = require("./specs.cjs")
const solidity = require("./solidity.cjs")
const utils = require("../src/utils.cjs")

module.exports = {
  getArtifacts: (network) => {
    let res = artifacts.default
    utils.getNetworkTagsFromString(network).forEach(net => {
      res = merge(res, artifacts[net])
    })
    return res
  },
  getCompilers: (network) => {
    let res = solidity.default
    utils.getNetworkTagsFromString(network).forEach(net => {
      res = merge(res, solidity[net])
    })
    return res
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
    let res = specs.default
    utils.getNetworkTagsFromString(network).forEach(net => {
      res = merge(res, specs[net])
    })
    return res
  },
  artifacts,
  solidity,
  specs,
}
