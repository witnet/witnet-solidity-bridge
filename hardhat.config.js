import hardhatVerify from "@nomicfoundation/hardhat-verify";

import settings from "./settings/index"
import utils from "./src/utils"

const [, target] = utils.getRealmNetworkFromArgs()

const networks = Object.fromEntries(
  Object.entries(settings.getNetworks())
    .map(([network, config]) => {
      return [network, {
        chainId: config.network_id,
        chainType: config?.chain_type || "generic",
        gas: config?.gas,
        gasPrice: config?.gasPrice,
        type: "http",
        url: `http://${config?.host || "localhost"}:${config?.port || 8545}`,
      }]
    })
)

const chainDescriptors = Object.fromEntries(
  Object.entries(settings.getNetworks())
    .filter(([, config]) => config?.verify !== undefined)
    .map(([network, config]) => { 
      return [
        config.network_id,
        {
          name: network,
          blockExplorers: {
            etherscan: {
              apiUrl: config?.verify.apiUrl,
              url: config?.verify.explorerUrl,
            }
          }
        }
      ]
    })
)

export default {
  chainDescriptors,
  paths: {
    sources: "./contracts",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  plugins: [
    hardhatVerify,
  ],
  networks,
  solidity: settings.getCompilers(target),
  verify: {
    blockscout: {
      enabled: true,
    },
    etherscan: {
      apiKey: process.env.ETHERSCAN_API_KEY_V2,
    },
    sourcify: {
      enabled: false,
      apiUrl: "https://sourcify.dev/server",
      browserUrl: "https://repo.sourcify.dev",
    },
  },
}
