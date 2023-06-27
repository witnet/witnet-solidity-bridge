module.exports = {
  artifacts: {
    default: {
      WitnetBytecodes: "WitnetBytecodesDefault",
      WitnetPriceFeeds: "WitnetPriceFeedsUpgradable",
      WitnetRandomness: "WitnetRandomnessProxiable",
      WitnetRequestBoard: "WitnetRequestBoardTrustableDefault",
      WitnetRequestFactory: "WitnetRequestFactoryDefault",
    },
    boba: {
      WitnetRequestBoard: "WitnetRequestBoardTrustableOvm2",
    },
    optimism: {
      WitnetRequestBoard: "WitnetRequestBoardTrustableOvm2",
    },
    reef: {
      WitnetRequestBoard: "WitnetRequestBoardTrustableReef",
    },
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
    conflux: {
      solc: {
        evmVersion: "petersburg",
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
    okxchain: {
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
    },
    arbitrum: {
      "arbitrum.goerli": {
        network_id: 421613,
        host: "localhost",
        port: 8517,
        skipDryRun: true,
      },
      "arbitrum.one": {
        network_id: 42161,
        host: "localhost",
        port: 9517,
        skipDryRun: true,
        verify: {
          apiUrl: "https://api.arbiscan.io/api",
          browserURL: "https://arbiscan.io/address",
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
      },
    },
    boba: {
      "boba.bnb.testnet": {
        network_id: 9728,
        host: "localhost",
        port: 8510,
        skipDryRun: true,
        verify: {
          apiUrl: "https://blockexplorer.testnet.bnb.boba.network/api",
          browserURL: "https://blockexplorer.testnet.bnb.boba.network/",
          apiKey: "MY_API_KEY",
        },
      },
      "boba.moonbeam.bobabase": {
        network_id: 1297,
        host: "localhost",
        port: 8518,
        skipDryRun: true,
      },
      "boba.ethereum.mainnet": {
        network_id: 288,
        host: "localhost",
        port: 9539,
        skipDryRun: true,
      },
      "boba.ethereum.rinkeby": {
        network_id: 28,
        host: "localhost",
        port: 8539,
        skipDryRun: true,
      },
      "boba.ethereum.goerli": {
        network_id: 2888,
        host: "localhost",
        port: 8515,
        skipDryRun: true,
      },
    },
    celo: {
      "celo.alfajores": {
        network_id: 44787,
        host: "localhost",
        port: 8538,
        skipDryRun: true,
      },
      "celo.mainnet": {
        network_id: 42220,
        host: "localhost",
        port: 9538,
        skipDryRun: true,
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
          apiUrl: "https://esc-testnet.elastos.io/api",
          browserURL: "https://esc-testnet.elastos.io/address",
          apiKey: "D75NV1MFN41XRSE9SWV9BA3QZKUD1U9RM3",
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
          apiKey: "D75NV1MFN41XRSE9SWV9BA3QZKUD1U9RM3",
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
          explorerUrl: "https://goerli.explorer.metisdevops.link//address",
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
          apiUrl: "http://api-testnet-zkevm.polygonscan.com/api",
          explorerUrl: "https://testnet-zkevm.polygonscan.com/address",
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
      "scroll.goerli": {
        host: "localhost",
        port: 8514,
        network_id: 534353,
        skipDryRun: true,
        gasPrice: 3000000,
        verify: {
          apiUrl: "https://blockscout.scroll.io/api",
          apiKey: "MY_API_KEY",
          explorerUrl: "https://blockscout.scroll.io/address",
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
