const artifacts = require("./artifacts")
const merge = require("lodash.merge")
const networks = require("./networks")
const specs = require("./specs")
const solidity = require("./solidity")
const utils = require("../src/utils")

module.exports = {
  getArtifacts: (network) => {
    let res = artifacts.default;
    utils.getNetworkTagsFromString(network).forEach(net => {
      res = merge(res, artifacts[net])
    });
    return res;
  },
  getCompilers: (network) => {
    let res = solidity.default;
    utils.getNetworkTagsFromString(network).forEach(net => {
      res = merge(res, solidity[net])
    });
    return res;
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
    let res = specs.default;
    utils.getNetworkTagsFromString(network).forEach(net => {
      res = merge(res, specs[net])
    });
    return res;
  },
  artifacts,
  solidity,
  specs,
}
