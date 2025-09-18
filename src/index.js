import { createRequire } from "module";
const require = createRequire(import.meta.url);
const addresses = require("../migrations/addresses.json")
const artifacts = require("../settings/artifacts.js").default
const constructorArgs = require("../migrations/constructorArgs.json")
const merge = require("lodash.merge")
const utils = require("./utils.js").default

export default {
  getNetworkAddresses: (network) => {
    let res = addresses?.default
    utils.getNetworkTagsFromString(network).forEach(net => {
      res = merge(res, addresses[net])
    })
    return res
  },
  getNetworkArtifacts: (network) => {
    let res = artifacts?.default
    utils.getNetworkTagsFromString(network).forEach(net => {
      res = merge(res, artifacts[net])
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
    WitAppliance:
      require("../artifacts/contracts/interfaces/IWitAppliance.sol/IWitAppliance.json").abi,
    WitOracle:
      require("../artifacts/contracts/WitOracle.sol/WitOracle.json").abi,
    WitOracleConsumer:
      require("../artifacts/contracts/interfaces/IWitOracleConsumer.sol/IWitOracleConsumer.json").abi,
    WitOracleRadonRegistry:
      require("../artifacts/contracts/WitOracleRadonRegistry.sol/WitOracleRadonRegistry.json").abi,
    WitOracleRadonRequestFactory:
      require("../artifacts/contracts/WitOracleRadonRequestFactory.sol/WitOracleRadonRequestFactory.json").abi,
    WitOracleRadonRequestModal:
      require("../artifacts/contracts/interfaces/IWitOracleRadonRequestModal.sol/IWitOracleRadonRequestModal.json").abi,
    WitOracleRadonRequestTemplate:
      require("../artifacts/contracts/interfaces/IWitOracleRadonRequestTemplate.sol/IWitOracleRadonRequestTemplate.json").abi,
    WitPriceFeeds:
      require("../artifacts/contracts/WitPriceFeeds.sol/WitPriceFeeds.json").abi,
    WitPriceFeedsLegacy:
      require("../artifacts/contracts/WitPriceFeedsLegacy.sol/WitPriceFeedsLegacy.json").abi,
    WitRandomness:
      require("../artifacts/contracts/WitRandomness.sol/WitRandomness.json").abi,
    WitRandomnessLegacy:
      require("../artifacts/contracts/WitRandomnessLegacy.sol/WitRandomnessLegacy.json").abi,
    WitnetUpgradableBase:
      require("../artifacts/contracts/core/WitnetUpgradableBase.sol/WitnetUpgradableBase.json").abi,
  },
  settings: require("../settings/index.js").default,
  utils,
}

function supportsNetwork (network) {
  return network && Object.keys(constructorArgs).includes(network.toLowerCase())
}

function supportedNetworks (ecosystem) {
  const networks = require("../settings/networks.js").default
  return Object.fromEntries(
    Object.keys(constructorArgs)
      .sort()
      .filter(network => network.indexOf(":") >= 0 && (!ecosystem || network.startsWith(ecosystem.toLowerCase()))) 
      .map(network => {
        return [
          network,
          {
            mainnet: networks[network]?.mainnet || false,
            network_id: networks[network].network_id,
            port: networks[network].port,
            symbol: networks[network]?.symbol || "ETH",
            verified: networks[network]?.verify?.explorerUrl,
          },
        ]
      })
  )
}
