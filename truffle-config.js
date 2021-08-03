// In order to load environment variables (e.g. API keys)
require("dotenv").config()
const statics = require("./migrations/settings")

module.exports = {
  build_directory: "./build/" + (process.env.WITNET_EVM_REALM || "evm") + "/",
  migrations_directory: "./migrations/scripts/",
  networks: statics.networks[process.env.WITNET_EVM_REALM || "default"],
  mocha: {
    reporter: "eth-gas-reporter",
    reporterOptions: {
      coinmarketcap: process.env.COINMARKETCAP_API_KEY,
      currency: "USD",
      gasPrice: 100,
      excludeContracts: ["Migrations"],
      src: "contracts",
    },
    timeout: 100000,
    useColors: true,
  },
  compilers: {
    solc: {
      version: statics.compilers[process.env.WITNET_EVM_REALM || "default"].version || "0.8.6",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
      evmVersion: statics.compilers[process.env.WITNET_EVM_REALM || "default"].evmVersion || "petersburg",
    },
  },
}
