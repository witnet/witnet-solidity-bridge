// In order to load environment variables (e.g. API keys)
require('dotenv').config();

module.exports = {
  networks: {
    test: {
      provider: require("ganache-cli").provider({ gasLimit: 100000000, seed: 1234 }),
      network_id: "*",
    },
    development: {
      provider: require("ganache-cli").provider({ gasLimit: 100000000, seed: 1234 }),
      network_id: "*",
    },
    local: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
    },
    ropsten: {
      network_id: 3,       // Ropsten's id
      host: "127.0.0.1",   // Localhost (default: none)
      port: 8545,          // Standard Ethereum port (default: none)
      gas: 8000029,        // Ropsten has a lower block limit than mainnet
      confirmations: 2,    // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
    },
  },
  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },
  // Configure your compilers
  compilers: {
    solc: {
      // version: "0.5.1",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
        },
      //  evmVersion: "byzantium"
      }
    },
  },
  plugins: [
    'truffle-verify',
  ],
  api_keys: {
    etherscan: process.env.ETHERSCAN_API_KEY,
  }
}
