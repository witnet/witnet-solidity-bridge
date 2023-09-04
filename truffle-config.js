const { merge } = require("lodash")
const settings = require("./migrations/witnet.settings")
const utils = require("./scripts/utils")

const rn = utils.getRealmNetworkFromArgs()
const realm = rn[0]; const network = rn[1]
if (!settings.networks[realm] || !settings.networks[realm][network]) {
  if (network !== "development" && network !== "test") {
    console.error(
      `Fatal: network "${realm}:${network}"`,
      "configuration not found in \"./migrations/witnet.settings.js#networks\""
    )
    process.exit(1)
  }
}
console.info(`
Targetting "${realm.toUpperCase()}" realm
===================${"=".repeat(realm.length)}`)
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
    timeout: 300000,
    useColors: true,
  },
  plugins: [
    "truffle-plugin-verify",
  ],
  api_keys: {
    arbiscan: process.env.ARBISCAN_API_KEY,
    bobascan: process.env.BOBASCAN_API_KEY,
    celo: process.env.CELOSCAN_API_KEY,
    cronos: process.env.CRONOSCAN_API_KEY,
    etherscan: process.env.ETHERSCAN_API_KEY,
    moonscan: process.env.MOONSCAN_API_KEY,
    polygonscan: process.env.POLYGONSCAN_API_KEY,
  },
}
