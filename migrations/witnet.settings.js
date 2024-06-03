module.exports = {
  artifacts: {
    default: {
      WitnetBytecodes: "WitnetBytecodesDefault",
      WitnetPriceFeeds: "WitnetPriceFeedsBypassV20:",
      WitnetRandomness: "WitnetRandomnessProxiable",
      WitnetRequestBoard: "WitnetRequestBoardBypassV20:WitnetRequestBoardTrustableDefault",
      WitnetRequestFactory: "WitnetRequestFactoryDefault",
    },
    boba: {
      WitnetRequestBoard: "WitnetRequestBoardTrustableOvm2",
    },
    "conflux.core.testnet": {
      WitnetRequestFactory: "WitnetRequestFactoryCfxCore",
    },
    "conflux.core.mainnet": {
      WitnetRequestFactory: "WitnetRequestFactoryCfxCore",
    },
    mantle: {
      WitnetRequestBoard: "WitnetRequestBoardBypassV20:WitnetRequestBoardTrustableOvm2",
    },
    "okx.x1.sepolia": {
      WitnetBytecodes: "WitnetBytecodesNoSha256",
    },
    optimism: {
      WitnetRequestBoard: "WitnetRequestBoardBypassV20:WitnetRequestBoardTrustableOvm2",
    },
    "polygon.zkevm.goerli": {
      WitnetBytecodes: "WitnetBytecodesNoSha256",
    },
    "polygon.zkevm.mainnet": {
      WitnetBytecodes: "WitnetBytecodesNoSha256",
    },
    reef: {
      WitnetRequestBoard: "WitnetRequestBoardBypassV20:WitnetRequestBoardTrustableReef",
    },
    scroll: {
      WitnetBytecodes: "WitnetBytecodesNoSha256",
    },
    "syscoin.rollux.testnet": {
      WitnetRequestBoard: "WitnetRequestBoardBypassV20:WitnetRequestBoardTrustableOvm2",
    }
  },
  compilers: {
    default: {
      solc: {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  constructorParams: {
    default: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 133000,
      ],
    },
    avalanche: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 155000,
      ],
    },
    celo: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 114000,
      ],
    },
    conflux: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 78500,
      ],
    },
    "conflux.espace.testnet": {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 225000,
      ],
    },
    "conflux.espace.mainnet": {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 225000,
      ],
    },
    cronos: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 137500,
      ],
    },
    dogechain: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 85000,
      ],
    },
    harmony: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 530000,
      ],
    },
    hsc: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 85000,
      ],
    },
    kcc: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 92500,
      ],
    },
    klaytn: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 105000,
      ],
    },
    meter: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 85000,
      ],
    },
    metis: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 134800,
      ],
    },
    moonbeam: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 115000,
      ],
    },
    okx: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 145000,
      ],
    },
    optimism: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 135000,
      ],
    },
    reef: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ "0x3100A1CAC7EF19DC",
      ],
    },
    ultron: {
      WitnetRequestBoard: [
        /* _reportResultGasLimit */ 83949,
      ],
    },
  },
  networks: {
    default: {
      "ethereum.goerli": {
        network_id: 5,
        host: "localhost",
        port: 8545,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api-goerli.etherscan.io/",
          browserURL: "https://goerli.etherscan.io/",
        },
      },
      "ethereum.kovan": {
        network_id: 42,
        host: "localhost",
        port: 8542,
        skipDryRun: true,
      },
      "ethereum.mainnet": {
        network_id: 1,
        host: "localhost",
        port: 9545,
        skipDryRun: true,
      },
      "ethereum.rinkeby": {
        network_id: 4,
        host: "localhost",
        port: 8544,
        skipDryRun: true,
      },
      "ethereum.ropsten": {
        network_id: 3,
        host: "localhost",
        port: 8543,
      },
      "ethereum.sepolia": {
        network_id: 11155111,
        host: "localhost",
        port: 8506,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api-sepolia.etherscan.io/api",
          browserURL: "https://sepolia.etherscan.io/",
        },
      },
    },
    arbitrum: {
      "arbitrum.goerli": {
        network_id: 421613,
        host: "localhost",
        port: 8517,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api-goerli.arbiscan.io/",
          browserURL: "https://goerli.arbiscan.io/",
        },
      },
      "arbitrum.one": {
        network_id: 42161,
        host: "localhost",
        port: 9517,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api.arbiscan.io/api",
          browserURL: "https://arbiscan.io/",
        },
      },
    },
    avalanche: {
      "avalanche.mainnet": {
        network_id: 43114,
        host: "localhost",
        port: 9533,
        skipDryRun: true,
        // gasPrice: 75 * 10 ** 9,
        verify: {
          apiKey: process.env.ETHERSCAN_ROUTESCAN_API_KEY,
          apiUrl: "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan/api",
          explorerUrl: "https://snowtrace.io/",
        },
      },
      "avalanche.testnet": {
        network_id: 43113,
        host: "localhost",
        port: 8533,
        skipDryRun: true,
        gasPrice: 30 * 10 ** 9,
        verify: {
          apiKey: "MY_API_KEY",
          apiUrl: "https://api-testnet.snowtrace.io/",
          browserURL: "https://testnet.snowtrace.io/",
        },
      },
    },
    boba: {
      "boba.bnb.testnet": {
        network_id: 9728,
        host: "localhost",
        port: 8510,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api.routescan.io/v2/network/testnet/evm/9728/etherscan",
          browserURL: "https://boba.testnet.routescan.io/",
        },
      },
      "boba.bnb.mainnet": {
        network_id: 56288,
        host: "localhost",
        port: 9510,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api.routescan.io/v2/network/mainnet/evm/56288/etherscan",
          explorerUrl: "https://bobascan.com/",
          apiKey: "MY_API_KEY",
        },
      },
      "boba.ethereum.mainnet": {
        network_id: 288,
        host: "localhost",
        port: 9539,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api.routescan.io/v2/network/mainnet/evm/all/etherscan",
          browserURL: "https://bobascan.com/address/",
          apiKey: "MY_API_KEY",
        },
      },
      "boba.ethereum.goerli": {
        network_id: 2888,
        host: "localhost",
        port: 8515,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api.routescan.io/v2/network/testnet/evm/2888/etherscan",
          browserURL: "https://boba.testnet.routescan.io/",
        },
      },
    },
    celo: {
      "celo.alfajores": {
        network_id: 44787,
        host: "localhost",
        port: 8538,
        skipDryRun: true,
        verify: {
          apiKey: process.env.CELOSCAN_API_KEY,
          apiUrl: "https://api-alfajores.celoscan.io/api",
          browserURL: "https://alfjores.celoscan.io/",
        },
      },
      "celo.mainnet": {
        network_id: 42220,
        host: "localhost",
        port: 9538,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api.celoscan.io/api",
          explorerUrl: "https://celoscan.io/",
        },
      },
    },
    conflux: {
      "conflux.core.testnet": {
        host: "localhost",
        port: 8540,
        network_id: 1,
        gasPrice: 10 ** 9,
        skipDryRun: true,
      },
      "conflux.core.mainnet": {
        host: "localhost",
        port: 9540,
        network_id: 1029,
        gasPrice: 10,
        skipDryRun: true,
      },
      "conflux.espace.testnet": {
        host: "localhost",
        port: 8529,
        network_id: 71,
        skipDryRun: true,
        // networkCheckTimeout: 999999,
        gas: 15000000,
        verify: {
          apiKey: "espace",
          apiUrl: "https://evmapi-testnet.confluxscan.io/api/",
          browserURL: "https://evmtestnet.confluxscan.io/",
        },
      },
      "conflux.espace.mainnet": {
        host: "localhost",
        port: 9529,
        network_id: 1030,
        skipDryRun: true,
        gas: 15000000,
        verify: {
          apiKey: "espace",
          apiUrl: "https://evmapi.confluxscan.io/api",
          explorerUrl: "https://evm.confluxscan.io/address",
        },
      },
    },
    cronos: {
      "cronos.testnet": {
        host: "localhost",
        port: 8530,
        network_id: 338,
        skipDryRun: true,
        verify: {
          apiUrl: "https://cronos.org/explorer/testnet3/api",
          browserURL: "https://cronos.org/explorer/testnet3",
        },
      },
      "cronos.mainnet": {
        host: "localhost",
        port: 9530,
        network_id: 25,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api.cronoscan.com/api",
          explorerUrl: "https://cronoscan.com",
        },
      },
    },
    cube: {
      "cube.testnet": {
        host: "localhost",
        port: 8522,
        network_id: 1819,
        skipDryRun: true,
      },
      "cube.mainnet": {
        host: "localhost",
        port: 9522,
        network_id: 1818,
        skipDryRun: true,
        gas: 6000000,
        gasPrice: 250 * 10 ** 9,
      },
    },
    dogechain: {
      "dogechain.testnet": {
        host: "localhost",
        port: 8519,
        network_id: 568,
        skipDryRun: true,
        gas: 6000000,
        verify: {
          apiKey: "MY_API_KEY",
          apiUrl: "http://explorer-testnet.dogechain.dog/api",
          browserURL: "https://explorer-testnet.dogechain.dog/",
        },
      },
      "dogechain.mainnet": {
        host: "localhost",
        port: 9519,
        network_id: 2000,
        skipDryRun: true,
      },
    },
    elastos: {
      "elastos.testnet": {
        host: "localhost",
        port: 8513,
        network_id: 21,
        skipDryRun: true,
        verify: {
          apiKey: "MY_API_KEY",
          apiUrl: "https://esc-testnet.elastos.io/api",
          browserURL: "https://esc-testnet.elastos.io/address",
        },
      },
      "elastos.mainnet": {
        host: "localhost",
        port: 9513,
        network_id: 20,
        skipDryRun: true,
        verify: {
          apiUrl: "https://esc.elastos.io/api",
          explorerUrl: "https://esc.elastos.io/",
        },
      },
    },
    fuse: {
      "fuse.testnet": {
        host: "localhost",
        port: 8511,
        network_id: 123,
        skipDryRun: true,
        verify: {
          apiUrl: "https://explorer.fusespark.io/api",
          browserURL: "https://explorer.fusespark.io/address",
          apiKey: "MY_API_KEY",
        },
      },
    },
    gnosis: {
      "gnosis.testnet": {
        host: "localhost",
        port: 8509,
        network_id: 10200,
        skipDryRun: true,
        verify: {
          apiUrl: "https://gnosis-chiado.blockscout.com/api",
          browserURL: "https://gnosis-chiado.blockscout.com/address",
          apiKey: "MY_API_KEY",
        },
      },
    },
    harmony: {
      "harmony.testnet#0": {
        host: "localhost",
        port: 8534,
        network_id: 1666700000,
        skipDryRun: true,
      },
    },
    hsc: {
      "hsc.testnet": {
        host: "localhost",
        port: 8524,
        network_id: 170,
        skipDryRun: true,
      },
      "hsc.mainnet": {
        host: "localhost",
        port: 9524,
        network_id: 70,
        skipDryRun: true,
      },
    },
    kava: {
      "kava.testnet": {
        host: "localhost",
        port: 8526,
        network_id: 2221,
        skipDryRun: true,
        verify: {
          apiKey: "MY_API_KEY",
          apiUrl: "https://explorer.testnet.kava.io/api",
          browserURL: "https://explorer.testnet.kava.io/",
        },
      },
      "kava.mainnet": {
        host: "localhost",
        port: 9526,
        network_id: 2222,
        skipDryRun: true,
        verify: {
          apiKey: "MY_API_KEY",
          apiUrl: "https://explorer.kavalabs.io/api",
          explorerUrl: "https://explorer.kavalabs.io/",
        },
      },
    },
    kcc: {
      "kcc.testnet": {
        host: "localhost",
        port: 8537,
        network_id: 322,
        gasPrice: 10 ** 10,
        skipDryRun: true,
        verify: {
          apiKey: "MY_API_KEY",
          apiUrl: "https://scan-testnet.kcc.network/api",
          browserURL: "https://scan-testnet.kcc.network/",
        },
      },
      "kcc.mainnet": {
        host: "localhost",
        port: 9537,
        network_id: 321,
        gasPrice: 10 ** 10,
        skipDryRun: true,
        verify: {
          apiKey: "MY_API_KEY",
          apiUrl: "https://scan.kcc.io/api",
          browserURL: "https://scan.kcc.io/",
        },
      },
    },
    klaytn: {
      "klaytn.testnet": {
        host: "localhost",
        port: 8527,
        network_id: 1001,
        skipDryRun: true,
        gasPrice: 0,
      },
      "klaytn.mainnet": {
        host: "localhost",
        port: 9527,
        network_id: 8217,
        skipDrynRun: true,
        gasPrice: 0,
      },
    },
    mantle: {
      "mantle.testnet": {
        host: "localhost",
        port: 8508,
        network_id: 5001,
        skipDryRun: true,
        verify: {
          apiKey: "MY_API_KEY",
          apiUrl: "https://explorer.testnet.mantle.xyz/api",
          explorerUrl: "https://explorer.testnet.mantle.xyz/address",
        },
      },
      "mantle.mainnet": {
        host: "localhost",
        port: 9508,
        network_id: 5000,
        skipDryRun: true,
        verify: {
          apiKey: "MY_API_KEY",
          apiUrl: "https://explorer.mantle.xyz/api",
          explorerUrl: "https://explorer.mantle.xyz/address",
        },
      },
    },
    metis: {
      "metis.mainnet": {
        host: "localhost",
        port: 9536,
        network_id: 1088,
        skipDryRun: true,
      },
      "metis.goerli": {
        host: "localhost",
        port: 8536,
        network_id: 599,
        skipDryRun: true,
        verify: {
          apiKey: "MY_API_KEY",
          apiUrl: "https://goerli.explorer.metisdevops.link/api",
          explorerUrl: "https://goerli.explorer.metisdevops.link/address",
        },
      },
    },
    meter: {
      "meter.testnet": {
        host: "localhost",
        port: 8523,
        network_id: 83,
        skipDryRun: true,
      },
      "meter.mainnet": {
        host: "localhost",
        port: 9523,
        network_id: 82,
        skipDryRun: true,
      },
    },
    moonbeam: {
      "moonbeam.mainnet": {
        host: "localhost",
        port: 9531,
        network_id: 1284,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api-moonbeam.moonscan.io/api",
          explorerUrl: "https://moonscan.io/",
        },
      },
      "moonbeam.moonriver": {
        host: "localhost",
        port: 7531,
        network_id: 1285,
        skipDrynRun: true,
        verify: {
          apiUrl: "https://api-moonriver.moonscan.io/api",
          explorerUrl: "https://moonriver.moonscan.io/",
        },
      },
      "moonbeam.moonbase": {
        host: "localhost",
        port: 8531,
        network_id: 1287,
        skipDryRun: true,
        gasPrice: 3 * 10 ** 9,
      },
    },
    okx: {
      "okx.okxchain.testnet": {
        host: "localhost",
        port: 8528,
        network_id: 65,
        skipDryRun: true,
      },
      "okx.okxchain.mainnet": {
        host: "localhost",
        port: 9528,
        network_id: 66,
        skipDryRun: true,
      },
      "okx.x1.sepolia": {
        host: "localhost",
        port: 8505,
        network_id: 195,
        skipDryRun: true,
      },
    },
    optimism: {
      "optimism.goerli": {
        host: "localhost",
        port: 8520,
        network_id: 420,
        skipDryRun: true,
        verify: {
          apiKey: "MY_API_KEY",
          apiUrl: "https://optimism-goerli.blockscout.com/api",
          explorerUrl: "https://optimism-goerli.blockscout.com/",
        },
      },
      "optimism.sepolia": {
        host: "localhost",
        port: 8503,
        network_id: 11155420,
        verify: {
          apiKey: process.env.ETHERSCAN_OPTIMISM_API_KEY,
          apiUrl: "https://api-sepolia-optimistic.etherscan.io/api",
          explorerUrl: "https://sepolia-optimism.etherscan.io/address",
        },
      },
      "optimism.mainnet": {
        host: "localhost",
        port: 9520,
        network_id: 10,
        skipDryRun: true,
        verify: {
          apiKey: process.env.ETHERSCAN_OPTIMISM_API_KEY,
          apiUrl: "https://api-optimistic.etherscan.io/api",
          explorerUrl: "https://optimistic.etherscan.io",
        },
      },
    },
    polygon: {
      "polygon.goerli": {
        host: "localhost",
        port: 8535,
        network_id: 80001,
        skipDryRun: true,
      },
      "polygon.mainnet": {
        host: "localhost",
        port: 9535,
        network_id: 137,
        skipDryRun: true,
        verify: {
          apiKey: process.env.ETHERSCAN_POLYGON_API_KEY,
          apiUrl: "https://api.polygonscan.com/api",
          explorerUrl: "https://polygonscan.com/",
        },
      },
      "polygon.zkevm.goerli": {
        host: "localhost",
        port: 8512,
        network_id: 1442,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api-testnet-zkevm.polygonscan.com/api",
          explorerUrl: "https://testnet-zkevm.polygonscan.com/address",
        },
      },
      "polygon.zkevm.mainnet": {
        host: "localhost",
        port: 9512,
        network_id: 1101,
        skipDryRun: true,
        // gasPrice: 50 * 10 ** 9,
        verify: {
          apiUrl: "https://api-zkevm.polygonscan.com/api",
          explorerUrl: "https://zkevm.polygonscan.com/address/",
        },
      },
    },
    reef: {
      "reef.testnet": {
        host: "localhost",
        port: 8532,
        network_id: 13939,
        skipDryRun: true,
      },
      "reef.mainnet": {
        host: "localhost",
        port: 9532,
        network_id: 13939,
        skipDryRun: true,
      },
    },
    scroll: {
      "scroll.sepolia": {
        host: "localhost",
        port: 8514,
        network_id: 534351,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api-sepolia.scrollscan.com/api",
          explorerUrl: "https://sepolia.scrollscan.com/",
        },
      },
      "scroll.mainnet": {
        host: "localhost",
        port: 9514,
        network_id: 534352,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api.scrollscan.com/api",
          explorerUrl: "https://scrollscan.com/address",
        },
      },
    },
    smartbch: {
      "smartbch.amber": {
        host: "localhost",
        port: 8525,
        network_id: 10001,
        skipDryRun: true,
      },
      "smartbch.mainnet": {
        host: "localhost",
        port: 9525,
        network_id: 10000,
        skipDryRun: true,
      },
    },
    syscoin: {
      "syscoin.testnet": {
        host: "localhost",
        port: 8521,
        network_id: 5700,
        skipDryRun: true,
      },
      "syscoin.mainnet": {
        host: "localhost",
        port: 9521,
        network_id: 57,
        skipDryRun: true,
      },
      "syscoin.rollux.testnet": {
        host: "localhost",
        port: 8507,
        network_id: 57000,
        skipDryRun: true,
        verify: {
          apiKey: "abc",
          apiUrl: "https://rollux.tanenbaum.io/api",
          explorerUrl: "https://rollux.tanenbaum.io/address/",
        },
      },
    },
    ten: {
      "ten.testnet": {
        host: "localhost",
        port: 8504,
        network_id: 443,
        skipDryRun: true,
        gas: 6000000,
        gasPrice: 10,
      },
    },
    ultron: {
      "ultron.testnet": {
        host: "localhost",
        port: 8516,
        network_id: 1230,
        skipDryRun: true,
      },
      "ultron.mainnet": {
        host: "localhost",
        port: 9516,
        network_id: 1231,
        skipDryRun: true,
      },
    },
  },
}
