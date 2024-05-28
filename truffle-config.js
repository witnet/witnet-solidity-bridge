const settings = require("./settings")
const utils = require("./src/utils")

const { ecosystem, network } = utils.getRealmNetworkFromArgs()
if (ecosystem) {
  const header = console.info(`${ecosystem.toUpperCase()}`)
  console.info(header)
  console.info("=".repeat(header.length))
}

module.exports = {
  build_directory: "./build/",
  contracts_directory: "./contracts/",
  migrations_directory: "./migrations/scripts/",
  networks: settings.getNetworks(network),
  compilers: {
    solc: settings.getCompilers(network),
  },
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
    arbiscan: process.env.ETHERSCAN_ARBISCAN_API_KEY,
    basescan: process.env.ETHERSCAN_BASESCAN_API_KEY,
    bobascan: process.env.BOBASCAN_API_KEY,
    celoscan: process.env.ETHERSCAN_CELO_API_KEY,
    cronos: process.env.ETHERSCAN_CRONOS_API_KEY,
    cronoscan: process.env.ETHERSCAN_CRONOSCAN_API_KEY,
    elastos: process.env.ETHERSCAN_ELASTOS_API_KEY,
    etherscan: process.env.ETHERSCAN_API_KEY,
    kcc: process.env.ETHERSCAN_KCC_API_KEY,
    mantle: process.env.ETHERSCAN_MANTLE_API_KEY,
    moonscan: process.env.ETHERSCAN_MOONBEAM_API_KEY,
    oklink: process.env.ETHERSCAN_OKLINK_API_KEY,
    okx: process.env.ETHERSCAN_OKLINK_API_KEY,
    optimistic_etherscan: process.env.ETHERSCAN_OPTIMISM_API_KEY,
    polygonscan: process.env.ETHERSCAN_POLYGON_API_KEY,
    routescan: process.env.ETHERSCAN_ROUTESCAN_API_KEY,
    scrollscan: process.env.ETHERSCAN_SCROLL_API_KEY,
  },
}
