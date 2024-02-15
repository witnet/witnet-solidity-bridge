module.exports = {
  default: {
    host: "localhost",
    skipDryRun: true,
  },
  "arbitrum:goerli": {
    network_id: 421613,
    port: 8517,
    verify: {
      apiUrl: "https://api-goerli.arbiscan.io/",
      browserURL: "https://goerli.arbiscan.io/",
    },
  },
  "arbitrum:one": {
    network_id: 42161,
    port: 9517,
  },
  "avalanche:mainnet": {
    network_id: 43114,
    port: 9533,
  },
  "avalanche:testnet": {
    network_id: 43113,
    port: 8533,
    verify: {
      apiUrl: "https://api.arbiscan.io/api",
      browserURL: "https://arbiscan.io/",
    },
  },
  "boba:bnb:testnet": {
    network_id: 9728,
    port: 8510,
    verify: {
      apiUrl: "https://api.routescan.io/v2/network/testnet/evm/2888/etherscan",
      browserURL: "https://boba.testnet.routescan.io/",
    },
  },
  "boba:bnb:mainnet": {
    network_id: 56288,
    port: 9510,
    verify: {
      apiUrl: "https://blockexplorer.bnb.boba.network/api",
      browserURL: "https://blockexplorer.bnb.boba.network/",
      apiKey: "MY_API_KEY",
    },
  },
  "boba:ethereum:mainnet": {
    network_id: 288,
    port: 9539,
    verify: {
      apiUrl: "https://api.routescan.io/v2/network/mainnet/evm/all/etherscan",
      browserURL: "https://bobascan.com/address/",
      apiKey: "MY_API_KEY",
    },
  },
  "boba:ethereum:goerli": {
    network_id: 2888,
    port: 8515,
    verify: {
      apiUrl: "https://api.routescan.io/v2/network/testnet/evm/2888/etherscan",
      browserURL: "https://boba.testnet.routescan.io/",
    },
  },
  "celo:alfajores": {
    network_id: 44787,
    port: 8538,
  },
  "celo:mainnet": {
    network_id: 42220,
    port: 9538,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://explorer.celo.org/alfajores/api",
      browserURL: "https://explorer.celo.org/alfajores/",
    },
  },
  "conflux:core:testnet": {
    port: 8540,
    network_id: 1,
    gasPrice: 10,
  },
  "conflux:core:mainnet": {
    port: 9540,
    network_id: 1029,
    gasPrice: 10,
    verify: {
      apiUrl: "https://explorer.celo.org/mainnet/api",
      browserURL: "https://explorer.celo.org/mainnet/",
    },
  },
  "conflux:espace:testnet": {
    port: 8529,
    network_id: 71,
    networkCheckTimeout: 999999,
    gas: 15000000,
  },
  "conflux:espace:mainnet": {
    port: 9529,
    network_id: 1030,
    networkCheckTimeout: 999999,
    gas: 15000000,
  },
  "cronos:testnet": {
    port: 8530,
    network_id: 338,
    verify: {
      apiUrl: "https://cronos.org/explorer/testnet3/api",
      browserURL: "https://cronos.org/explorer/testnet3",
    },
  },
  "cronos:mainnet": {
    port: 9530,
    network_id: 25,
  },
  "cube:testnet": {
    port: 8522,
    network_id: 1819,
  },
  "ethereum:goerli": {
    network_id: 5,
    port: 8545,
    verify: {
      apiUrl: "https://api-goerli.etherscan.io/",
      browserURL: "https://goerli.etherscan.io/",
    },
  },
  "ethereum:mainnet": {
    network_id: 1,
    port: 9545,
  },
  "ethereum:sepolia": {
    network_id: 11155111,
    port: 8506,
    verify: {
      apiUrl: "https://api-sepolia.etherscan.io/api",
      browserURL: "https://sepolia.etherscan.io/",
    },
  },
  "dogechain:testnet": {
    port: 8519,
    network_id: 568,
    gas: 6000000,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "http://explorer-testnet.dogechain.dog/api",
      browserURL: "https://explorer-testnet.dogechain.dog/",
    },
  },
  "dogechain:mainnet": {
    port: 9519,
    network_id: 2000,
  },
  "elastos:testnet": {
    port: 8513,
    network_id: 21,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://esc-testnet.elastos.io/api",
      browserURL: "https://esc-testnet.elastos.io/address",
    },
  },
  "elastos:mainnet": {
    port: 9513,
    network_id: 20,
    verify: {
      apiUrl: "https://esc.elastos.io/api",
      browserURL: "https://esc.elastos.io/address",
    },
  },
  "fuse:testnet": {
    port: 8511,
    network_id: 123,
    verify: {
      apiUrl: "https://explorer.fusespark.io/api",
      browserURL: "https://explorer.fusespark.io/address",
      apiKey: "MY_API_KEY",
    },
  },
  "gnosis:testnet": {
    port: 8509,
    network_id: 10200,
    verify: {
      apiUrl: "https://gnosis-chiado.blockscout.com/api",
      browserURL: "https://gnosis-chiado.blockscout.com/address",
      apiKey: "MY_API_KEY",
    },
  },
  "harmony:testnet#0": {
    port: 8534,
    network_id: 1666700000,
  },
  "kava:testnet": {
    port: 8526,
    network_id: 2221,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://explorer.testnet.kava.io/api",
      browserURL: "https://explorer.testnet.kava.io/",
    },
  },
  "kava:mainnet": {
    port: 9526,
    network_id: 2222,
  },
  "kcc:testnet": {
    port: 8537,
    network_id: 322,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://scan-testnet.kcc.network/api",
      browserURL: "https://scan-testnet.kcc.network/",
    },
  },
  "kcc:mainnet": {
    port: 9537,
    network_id: 321,
  },
  "klaytn:testnet": {
    port: 8527,
    network_id: 1001,
  },
  "klaytn:mainnet": {
    port: 9527,
    network_id: 8217,
  },
  "mantle:testnet": {
    port: 8508,
    network_id: 5001,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://explorer.testnet.mantle.xyz/api",
      explorerUrl: "https://explorer.testnet.mantle.xyz/address",
    },
  },
  "mantle:mainnet": {
    port: 9508,
    network_id: 5000,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://explorer.mantle.xyz/api",
      explorerUrl: "https://explorer.mantle.xyz/address",
    },
  },
  "metis:mainnet": {
    port: 9536,
    network_id: 1088,
  },
  "metis:goerli": {
    port: 8536,
    network_id: 599,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://goerli.explorer.metisdevops.link/api",
      explorerUrl: "https://goerli.explorer.metisdevops.link/address",
    },
  },
  "meter:testnet": {
    port: 8523,
    network_id: 83,
  },
  "meter:mainnet": {
    port: 9523,
    network_id: 82,
  },
  "moonbeam:mainnet": {
    port: 9531,
    network_id: 1284,
  },
  "moonbeam:moonriver": {
    port: 7531,
    network_id: 1285,
  },
  "moonbeam:moonbase": {
    port: 8531,
    network_id: 1287,
  },
  "okxchain:testnet": {
    port: 8528,
    network_id: 65,
  },
  "okxchain:mainnet": {
    port: 9528,
    network_id: 66,
  },
  "optimism:goerli": {
    port: 8520,
    network_id: 420,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://optimism-goerli.blockscout.com/api",
      explorerUrl: "https://optimism-goerli.blockscout.com/",
    },
  },
  "optimism:mainnet": {
    port: 9520,
    network_id: 10,

  },
  "polygon:goerli": {
    port: 8535,
    network_id: 80001,
  },
  "polygon:mainnet": {
    port: 9535,
    network_id: 137,
  },
  "polygon:zkevm:goerli": {
    port: 8512,
    network_id: 1442,
    verify: {
      apiUrl: "https://api-testnet-zkevm.polygonscan.com/api",
      explorerUrl: "https://testnet-zkevm.polygonscan.com/address",
    },
  },
  "polygon:zkevm:mainnet": {
    port: 9512,
    network_id: 1101,
    verify: {
      apiUrl: "https://api-zkevm.polygonscan.com/api",
      explorerUrl: "https://zkevm.polygonscan.com/address/",
    },
  },
  "reef:testnet": {
    port: 8532,
    network_id: 13939,
  },
  "reef:mainnet": {
    port: 9532,
    network_id: 13939,
  },
  "scroll:sepolia": {
    port: 8514,
    network_id: 534351,
    verify: {
      apiUrl: "http://api-sepolia.scrollscan.io/api",
      explorerUrl: "https://sepolia.scrollscan.io/",
    },
  },
  "scroll:mainnet": {
    port: 9514,
    network_id: 534352,
    verify: {
      apiUrl: "https://api.scrollscan.com/api",
      explorerUrl: "https://scrollscan.com/address",
    },
  },
  "syscoin:testnet": {
    port: 8521,
    network_id: 5700,
  },
  "syscoin:mainnet": {
    port: 9521,
    network_id: 57,
  },
  "syscoin:rollux:testnet": {
    port: 8507,
    network_id: 57000,
    verify: {
      apiKey: "abc",
      apiUrl: "https://rollux.tanenbaum.io/api",
      explorerUrl: "https://rollux.tanenbaum.io/address/",
    },
  },
  "ten:testnet": {
    port: 8504,
    network_id: 443,
    gas: 6000000,
  },
  "ultron:testnet": {
    port: 8516,
    network_id: 1230,
  },
  "ultron:mainnet": {
    port: 9516,
    network_id: 1231,
  },
}
