import merge from "lodash.merge"

import artifacts from "./artifacts.js"
import networks from "./networks.js"
import { default as specs } from "./specs.js"
import solidity from "./solidity.js"
import utils from "../src/utils.js"

export default {
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
