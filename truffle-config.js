// In order to load environment variables (e.g. API keys)
require("dotenv").config()
const { merge } = require("lodash")
const settings = require("./migrations/settings.witnet")
const realm = process.env.WITNET_EVM_REALM ? process.env.WITNET_EVM_REALM.toLowerCase() : "default"

module.exports = {
  build_directory: `./build/${realm}/`,
  contracts_directory: "./contracts/",
  migrations_directory: "./migrations/scripts/",
  networks: settings.networks[realm],
  compilers: merge(settings.compilers.default, settings.compilers[realm]),
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
}
