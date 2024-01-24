module.exports = {
  artifacts: {
    default: {
      WitnetBytecodes: "WitnetBytecodesDefault",
      WitnetEncodingLib: "WitnetEncodingLib",
      WitnetErrorsLib: "WitnetErrorsLib",
      WitnetPriceFeeds: "WitnetPriceFeeds",
      WitnetPriceFeedsLib: "WitnetPriceFeedsLib",
      WitnetRandomness: "WitnetRandomness",
      WitnetRequestBoard: "WitnetRequestBoardTrustableDefault",
      WitnetRequestFactory: "WitnetRequestFactoryDefault",
    },
    boba: {
      WitnetRequestBoard: "WitnetRequestBoardTrustableOvm2",
    },
    conflux: {
      WitnetRequestFactory: "WitnetRequestFactoryCfxCore",
    },
    mantle: {
      WitnetRequestBoard: "WitnetRequestBoardTrustableOvm2",
    },
    optimism: {
      WitnetRequestBoard: "WitnetRequestBoardTrustableOvm2",
    },
    "polygon.zkevm.goerli": {
      WitnetBytecodes: "WitnetBytecodesNoSha256",
    },
    "polygon.zkevm.mainnet": {
      WitnetBytecodes: "WitnetBytecodesNoSha256",
    },
    reef: {
      WitnetRequestBoard: "WitnetRequestBoardTrustableReef",
    },
    scroll: {
      WitnetBytecodes: "WitnetBytecodesNoSha256",
    },
    "syscoin.rollux.testnet": {
      WitnetRequestBoard: "WitnetRequestBoardTrustableOvm2",
    },
  },
  compilers: {
    default: {
      solc: {
        version: "0.8.22",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: "paris",
        },
      },
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
        gasPrice: 75 * 10 ** 9,
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
          apiUrl: "https://api.routescan.io/v2/network/testnet/evm/2888/etherscan",
          browserURL: "https://boba.testnet.routescan.io/",
        },
      },
      "boba.bnb.mainnet": {
        network_id: 56288,
        host: "localhost",
        port: 9510,
        skipDryRun: true,
        verify: {
          apiUrl: "https://blockexplorer.bnb.boba.network/api",
          browserURL: "https://blockexplorer.bnb.boba.network/",
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
          apiKey: "MY_API_KEY",
          apiUrl: "https://explorer.celo.org/alfajores/api",
          browserURL: "https://explorer.celo.org/alfajores/",
        },
      },
      "celo.mainnet": {
        network_id: 42220,
        host: "localhost",
        port: 9538,
        skipDryRun: true,
        verify: {
          apiUrl: "https://explorer.celo.org/mainnet/api",
          browserURL: "https://explorer.celo.org/mainnet/",
        },
      },
    },
    conflux: {
      "conflux.core.testnet": {
        host: "localhost",
        port: 8540,
        network_id: 1,
        gasPrice: 10,
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
        networkCheckTimeout: 999999,
        gas: 15000000,
      },
      "conflux.espace.mainnet": {
        host: "localhost",
        port: 9529,
        network_id: 1030,
        skipDryRun: true,
        networkCheckTimeout: 999999,
        gas: 15000000,
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
          browserURL: "https://esc.elastos.io/address",
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
      },
      "moonbeam.moonriver": {
        host: "localhost",
        port: 7531,
        network_id: 1285,
        skipDrynRun: true,
      },
      "moonbeam.moonbase": {
        host: "localhost",
        port: 8531,
        network_id: 1287,
        skipDryRun: true,
        gasPrice: 3 * 10 ** 9,
      },
    },
    okxchain: {
      "okxchain.testnet": {
        host: "localhost",
        port: 8528,
        network_id: 65,
        skipDryRun: true,
      },
      "okxchain.mainnet": {
        host: "localhost",
        port: 9528,
        network_id: 66,
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
      "optimism.mainnet": {
        host: "localhost",
        port: 9520,
        network_id: 10,
        skipDryRun: true,
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
          apiUrl: "http://api-sepolia.scrollscan.io/api",
          explorerUrl: "https://sepolia.scrollscan.io/",
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
  specs: {
    default: {
      WitnetBytecodes: {
        libs: ["WitnetEncodingLib"],
        vanity: 172582,
      },
      WitnetRandomness: {
        vanity: 4,
      },
      WitnetRequestBoard: {
        immutables: {
          types: ["uint256", "uint256", "uint256", "uint256"],
          values: [
            /* _reportResultGasBase */ 58282,
            /* _reportResultWithCallbackGasBase */ 65273,
            /* _reportResultWithCallbackRevertGasBase */ 69546,
            /* _sstoreFromZeroGas */ 20000,
          ],
        },
        libs: ["WitnetErrorsLib"],
        vanity: 899032812, // => 0x000071F0c823bD30D2Bf4CD1E829Eba5A6070000
      },
      WitnetRequestFactory: {
        vanity: 178848,
      },
      WitnetPriceFeeds: {
        libs: ["WitnetPriceFeedsLib"],
        vanity: 5,
      },
    },
    avalanche: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 155000,
          ],
        },
      },
    },
    celo: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 114000,
          ],
        },
      },
    },
    conflux: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 78500,
          ],
        },
      },
    },
    "conflux.espace.testnet": {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 225000,
          ],
        },
      },
    },
    "conflux.espace.mainnet": {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 225000,
          ],
        },
      },
    },
    cronos: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 137500,
          ],
        },
      },
    },
    dogechain: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 85000,
          ],
        },
      },
    },
    harmony: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 530000,
          ],
        },
      },
    },
    hsc: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 85000,
          ],
        },
      },
    },
    kcc: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 92500,
          ],
        },
      },
    },
    klaytn: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 105000,
          ],
        },
      },
    },
    meter: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 85000,
          ],
        },
      },
    },
    metis: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 134800,
          ],
        },
      },
    },
    moonbeam: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 115000,
          ],
        },
      },
    },
    okxchain: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 145000,
          ],
        },
      },
    },
    optimism: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 135000,
          ],
        },
      },
    },
    reef: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ "0x3100A1CAC7EF19DC",
          ],
        },
      },
    },
    ultron: {
      WitnetRequestBoard: {
        immutables: {
          values: [
            /* _reportResultGasBase */ 83949,
          ],
        },
      },
    },
  },
}
