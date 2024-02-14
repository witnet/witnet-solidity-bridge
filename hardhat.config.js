require("@nomicfoundation/hardhat-verify")

const settings = require("./settings")
const utils = require("./src/utils")
const [, target] = utils.getRealmNetworkFromArgs()

module.exports = {
  networks: Object.fromEntries(
    Object.entries(settings.getNetworks())
      .map(([network, config]) => {
        return [network, {
          chainId: config.network_id,
          gas: config?.gas || "auto",
          gasPrice: config?.gasPrice || "auto",
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
        .filter(([, config]) => config?.verify)
        .map(([network, config]) => {
          const [ecosystem] = utils.getRealmNetworkFromString(network)
          return [network, config?.verify?.apiKey ?? `ETHERSCAN_${ecosystem.toUpperCase()}_API_KEY`]
        }),
    ),
    customChains: Object.entries(settings.getNetworks())
      .filter(([, config]) => config?.verify)
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
