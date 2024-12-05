module.exports = {
  default: {
    host: "localhost",
    skipDryRun: true,
  },
  "arbitrum:sepolia": {
    network_id: 421614,
    port: 8517,
    verify: {
      apiUrl: "https://api-sepolia.arbiscan.io/api",
      explorerUrl: "https://sepolia.arbiscan.io/",
    },
  },
  "arbitrum:one": {
    network_id: 42161,
    port: 9517,
    verify: {
      apiUrl: "https://api.arbiscan.io/api",
      explorerUrl: "https://arbiscan.io/",
    },
  },
  "avalanche:mainnet": {
    network_id: 43114,
    port: 9533,
    verify: {
      apiKey: process.env.ETHERSCAN_ROUTESCAN_API_KEY,
      apiUrl: "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan/api",
      explorerUrl: "https://snowtrace.io/",
    },
  },
  "avalanche:testnet": {
    network_id: 43113,
    port: 8533,
    verify: {
      apiKey: process.env.ETHERSCAN_ROUTESCAN_API_KEY,
      apiUrl: "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan/api",
      explorerUrl: "https://testnet.snowtrace.io/",
    },
  },
  "base:mainnet": {
    network_id: 8453,
    port: 9502,
    verify: {
      apiUrl: "https://api.basescan.org/api",
      explorerUrl: "https://basescan.com/",
    },
  },
  "base:sepolia": {
    network_id: 84532,
    port: 8502,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://base-sepolia.blockscout.com/api",
      explorerUrl: "https://base-sepolia.blockscout.com/",
    },
  },
  "boba:bnb:testnet": {
    network_id: 9728,
    port: 8510,
    confirmations: 4,
    verify: {
      apiUrl: "https://api.routescan.io/v2/network/testnet/evm/9728/etherscan",
      explorerUrl: "https://boba.testnet.routescan.io/",
    },
  },
  "boba:bnb:mainnet": {
    network_id: 56288,
    port: 9510,
    verify: {
      apiUrl: "https://api.routescan.io/v2/network/mainnet/evm/56288/etherscan",
      explorerUrl: "https://bobascan.com/",
      apiKey: "MY_API_KEY",
    },
  },
  "boba:eth:mainnet": {
    network_id: 288,
    port: 9539,
    verify: {
      apiUrl: "https://api.routescan.io/v2/network/mainnet/evm/288/etherscan",
      explorerUrl: "https://bobascan.com/address/",
      apiKey: "MY_API_KEY",
    },
  },
  "boba:eth:goerli": {
    network_id: 2888,
    port: 8515,
    verify: {
      apiUrl: "https://api.routescan.io/v2/network/testnet/evm/2888/etherscan",
      explorerUrl: "https://boba.testnet.routescan.io/",
    },
  },
  "celo:alfajores": {
    network_id: 44787,
    port: 8538,
    verify: {
      apiUrl: "https://api-alfajores.celoscan.io/api",
      explorerUrl: "https://alfjores.celoscan.io/",
    },
  },
  "celo:mainnet": {
    network_id: 42220,
    port: 9538,
    verify: {
      apiUrl: "https://api.celoscan.io/api",
      explorerUrl: "https://celoscan.io/",
    },
  },
  "conflux:core:testnet": {
    port: 8540,
    network_id: 1,
    verify: {
      apiUrl: "https://api-testnet.confluxscan.io",
      explorerUrl: "https://testnet.confluxscan.io/",
    },
  },
  "conflux:core:mainnet": {
    port: 9540,
    network_id: 1029,
    gasPrice: 10,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://api.confluxscan.io/",
      explorerUrl: "https://confluxscan.io/",
    },
  },
  "conflux:espace:testnet": {
    port: 8529,
    network_id: 71,
    // networkCheckTimeout: 999999,
    gas: 15000000,
    verify: {
      apiKey: "espace",
      apiUrl: "https://evmapi-testnet.confluxscan.io/api/",
      explorerUrl: "https://evmtestnet.confluxscan.io/",
    },
  },
  "conflux:espace:mainnet": {
    port: 9529,
    network_id: 1030,
    networkCheckTimeout: 999999,
    gas: 15000000,
    verify: {
      apiKey: "espace",
      apiUrl: "https://evmapi.confluxscan.io/api",
      explorerUrl: "https://evm.confluxscan.io/address",
    },
  },
  "cronos:testnet": {
    port: 8530,
    network_id: 338,
    verify: {
      apiKey: process.env.ETHERSCAN_CRONOS_API_KEY,
      apiUrl: "https://explorer-api.cronos.org/testnet/api/v1/hardhat/contract?apikey=G99km4eqHKfvEgpk6Lscsg3Y15QVLQLK",
      explorerUrl: "https://explorer.cronos.org/testnet",
    },
  },
  "cronos:mainnet": {
    port: 9530,
    network_id: 25,
    confirmations: 2,
    verify: {
      apiUrl: "https://api.cronoscan.com/api",
      explorerUrl: "https://cronoscan.com",
    },
  },
  "cube:testnet": {
    port: 8522,
    network_id: 1819,
  },
  "dogechain:testnet": {
    port: 8519,
    network_id: 568,
    gas: 6000000,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "http://explorer-testnet.dogechain.dog/api",
      explorerUrl: "https://explorer-testnet.dogechain.dog/",
    },
  },
  "dogechain:mainnet": {
    port: 9519,
    network_id: 2000,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "http://explorer.dogechain.dog/api",
      explorerUrl: "https://explorer.dogechain.dog/",
    },
  },
  "elastos:testnet": {
    port: 8513,
    network_id: 21,
    verify: {
      apiUrl: "https://esc-testnet.elastos.io/api",
      explorerUrl: "https://esc-testnet.elastos.io/address",
    },
  },
  "elastos:mainnet": {
    port: 9513,
    network_id: 20,
    verify: {
      apiUrl: "https://esc.elastos.io/api",
      explorerUrl: "https://esc.elastos.io/address",
    },
  },
  "ethereum:mainnet": {
    network_id: 1,
    port: 9545,
    verify: {
      apiUrl: "https://api.etherscan.io/api",
      explorerUrl: "https://etherscan.io/",
    },
  },
  "ethereum:sepolia": {
    network_id: 11155111,
    port: 8506,
    verify: {
      apiUrl: "https://api-sepolia.etherscan.io/api",
      explorerUrl: "https://sepolia.etherscan.io/",
    },
  },
  "fuse:testnet": {
    port: 8511,
    network_id: 123,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://explorer.fusespark.io/api",
      explorerUrl: "https://explorer.fusespark.io/address",
    },
  },
  "gnosis:mainnet": {
    port: 9509,
    network_id: 100,
    verify: {
      apiUrl: "https://api.gnosisscan.io/api",
      explorerUrl: "https://gnosisscan.io/address",
    },
  },
  "gnosis:testnet": {
    port: 8509,
    network_id: 10200,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://gnosis-chiado.blockscout.com/api",
      explorerUrl: "https://gnosis-chiado.blockscout.com/address",
    },
  },
  "kava:testnet": {
    port: 8526,
    network_id: 2221,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://testnet.explorer.kavalabs.io/api",
      explorerUrl: "https://testnet.explorer.kavalabs.io/",
    },
  },
  "kava:mainnet": {
    port: 9526,
    network_id: 2222,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://explorer.kavalabs.io/api",
      explorerUrl: "https://explorer.kavalabs.io/",
    },
  },
  "kcc:testnet": {
    port: 8537,
    network_id: 322,
    verify: {
      apiUrl: "https://scan-testnet.kcc.network/api",
      explorerUrl: "https://scan-testnet.kcc.network/",
    },
  },
  "kcc:mainnet": {
    port: 9537,
    network_id: 321,
    // verify: {
    //   apiUrl: "https://scan.kcc.io/api",
    //   explorerUrl: "https://scan.kcc.io/",
    // },
  },
  "klaytn:testnet": {
    port: 8527,
    network_id: 1001,
  },
  "klaytn:mainnet": {
    port: 9527,
    network_id: 8217,
  },
  "mantle:sepolia": {
    port: 8508,
    network_id: 5003,
    verify: {
      apiUrl: "https://api-sepolia.mantlescan.xyz/api",
      explorerUrl: "https://sepolia.mantlescan.xyz/",
    },
  },
  "mantle:mainnet": {
    port: 9508,
    network_id: 5000,
    verify: {
      apiUrl: "https://explorer.mantle.xyz/api",
      explorerUrl: "https://explorer.mantle.xyz/",
    },
  },
  "metis:mainnet": {
    port: 9536,
    network_id: 1088,
  },
  "metis:sepolia": {
    port: 8536,
    network_id: 59902,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://sepolia-explorer.metisdevops.link/api",
      // apiUrl: "https://api.routescan.io/v2/network/sepolia/evm/59902/etherscan",
      explorerUrl: "https://sepolia-explorer.metisdevops.link",
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
    verify: {
      apiUrl: "https://api-moonbeam.moonscan.io/api",
      explorerUrl: "https://moonscan.io/",
    },
  },
  "moonbeam:moonriver": {
    port: 7531,
    network_id: 1285,
    verify: {
      apiUrl: "https://api-moonriver.moonscan.io/api",
      explorerUrl: "https://moonriver.moonscan.io/",
    },
  },
  "moonbeam:moonbase": {
    port: 8531,
    network_id: 1287,
    gas: 15000000,
    verify: {
      apiUrl: "https://api-moonbase.moonscan.io/api",
      explorerUrl: "https://moonbase.moonscan.io/",
    },
  },
  "okx:oktchain:testnet": {
    port: 8528,
    network_id: 65,
    verify: {
      apiUrl: "https://www.oklink.com/api/explorer/v1/contract/verify/async/api",
      explorerUrl: "https://www.okx.com/explorer/oktc/",
    },
  },
  "okx:oktchain:mainnet": {
    port: 9528,
    network_id: 66,
    verify: {
      apiUrl: "https://www.oklink.com/api/explorer/v1/contract/verify/async/api/okctest",
      explorerUrl: "https://www.okx.com/explorer/oktc-test/",
    },
  },
  "okx:xlayer:sepolia": {
    port: 8505,
    network_id: 195,
    verify: {
      apiUrl: "https://www.okx.com/explorer/xlayer-test/api",
      explorerUrl: "https://www.okx.com/explorer/xlayer-test",
    },
  },
  "optimism:sepolia": {
    port: 8503,
    network_id: 11155420,
    confirmations: 2,
    verify: {
      apiKey: process.env.ETHERSCAN_OPTIMISM_API_KEY,
      apiUrl: "https://api-sepolia-optimistic.etherscan.io/api",
      explorerUrl: "https://sepolia-optimism.etherscan.io/address",
    },
  },
  "optimism:mainnet": {
    port: 9520,
    network_id: 10,
    confirmations: 3,
    verify: {
      apiKey: process.env.ETHERSCAN_OPTIMISM_API_KEY,
      apiUrl: "https://api-optimistic.etherscan.io/api",
      explorerUrl: "https://optimistic.etherscan.io/",
    },
  },
  "polygon:amoy": {
    port: 8535,
    network_id: 80002,
    verify: {
      apiKey: process.env.ETHERSCAN_POLYGON_API_KEY,
      apiUrl: "https://api-amoy.polygonscan.com/api",
      explorerUrl: "https://amoy.polygonscan.com/",
    },
  },
  "polygon:mainnet": {
    port: 9535,
    network_id: 137,
    verify: {
      apiKey: process.env.ETHERSCAN_POLYGON_API_KEY,
      apiUrl: "https://api.polygonscan.com/api",
      explorerUrl: "https://polygonscan.com/",
    },
  },
  "polygon:zkevm:goerli": {
    port: 8512,
    network_id: 1442,
    verify: {
      apiUrl: "https://api-testnet-zkevm.polygonscan.com/api",
      explorerUrl: "https://testnet-zkevm.polygonscan.com/",
    },
  },
  "polygon:zkevm:mainnet": {
    port: 9512,
    network_id: 1101,
    verify: {
      apiUrl: "https://api-zkevm.polygonscan.com/api",
      explorerUrl: "https://zkevm.polygonscan.com/",
    },
  },
  "scroll:sepolia": {
    port: 8514,
    network_id: 534351,
    verify: {
      apiUrl: "https://api-sepolia.scrollscan.com/api",
      explorerUrl: "https://sepolia.scrollscan.com/",
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
      explorerUrl: "https://rollux.tanenbaum.io",
    },
  },
  "ten:testnet": {
    port: 8504,
    network_id: 443,
    gas: 15000000,
  },
  "ultron:testnet": {
    port: 8516,
    network_id: 1230,
  },
  "ultron:mainnet": {
    port: 9516,
    network_id: 1231,
  },
  "worldchain:sepolia": {
    port: 8501,
    network_id: 4801,
    verify: {
      apiKey: "MY_API_KEY",
      apiUrl: "https://worldchain-sepolia.explorer.alchemy.com/api",
      explorerUrl: "https://worldchain-sepolia.explorer.alchemy.com/address",
    },    
  },
}
