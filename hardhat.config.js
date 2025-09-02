require("hardhat-gas-reporter")
require("@nomicfoundation/hardhat-ethers")
require("@nomicfoundation/hardhat-toolbox")
require("@nomicfoundation/hardhat-verify")

const settings = require("./settings")
const utils = require("./src/utils")
const [, target] = utils.getRealmNetworkFromArgs()

module.exports = {
  gasReporter: {
    enabled: true,
    includeIntrinsicGas: false,
  },
  paths: {
    sources: "./contracts",
  },
  networks: Object.fromEntries(
    Object.entries(settings.getNetworks())
      .map(([network, config]) => {
        return [network, {
          chainId: config.network_id,
          gas: config?.gas,
          gasPrice: config?.gasPrice,
          url: `http://${config?.host || "localhost"}:${config?.port || 8545}`,
        }]
      })
  ),
  solidity: settings.getCompilers(target),
  sourcify: {
    enabled: true,
    apiUrl: "https://sourcify.dev/server",
    browserUrl: "https://repo.sourcify.dev",
  },
  etherscan: {
    apiKey: Object.fromEntries(
      Object.entries(settings.getNetworks())
        .filter(([, config]) => config?.verify !== undefined)
        .map(([network, config]) => {
          const [ecosystem] = utils.getRealmNetworkFromString(network)
          const envar = `ETHERSCAN_${ecosystem.toUpperCase()}_API_KEY`
          return [network,
            config?.verify?.apiKey || process.env[envar] || process.env.ETHERSCAN_API_KEY || "MY_API_KEY",
          ]
        }),
    ),
    customChains: Object.entries(settings.getNetworks())
      .filter(([, config]) => config?.verify !== undefined)
      .map(([network, config]) => {
        return {
          network,
          chainId: config.network_id,
          urls: {
            apiURL: config?.apiUrl,
            browserURL: config?.browserUrl,
          },
        }
      }),
  },
}
