// In order to load environment variables (e.g. API keys)
module.exports = {
  contracts_directory: "./contracts/flattened/",
  networks: {
    test: {
      provider: require("ganache-cli").provider({ gasLimit: 100000000, seed: 1234 }),
      network_id: "*",
    },
    development: {
      provider: require("ganache-cli").provider({ gasLimit: 100000000, seed: 1234 }),
      network_id: "*",
    },
    ropsten: {
      network_id: 3,
      host: "localhost",
      port: 8543,
    },
    rinkeby: {
      network_id: 4,
      host: "localhost",
      port: 8544,
    },
    goerli: {
      network_id: 5,
      host: "localhost",
      port: 8545,
    },
    kovan: {
      network_id: 42,
      host: "localhost",
      port: 8542,
    },
    mainnet: {
      network_id: 1,
      host: "localhost",
      port: 9545,
      gasPrice: 20000000000, // 20 gwei
    },
    "conflux.testnet": {
      host: "localhost",
      port: 8540,
      network_id: 1,
      gasPrice: 10,
      skipDryRun: true,
    },
  },
  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },
  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.6", // Fetch exact version from solc-bin (default: truffle's version)
      settings: { // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
  plugins: [
    "truffle-verify",
  ],
  api_keys: {
    etherscan: process.env.ETHERSCAN_API_KEY,
  },
}
