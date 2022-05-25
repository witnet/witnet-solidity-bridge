const packageJson = require("../package.json")
module.exports = {
  artifacts: {
    default: {
      WitnetDecoderLib: "WitnetDecoderLib",
      WitnetParserLib: "WitnetParserLib",
      WitnetPriceRouter: "WitnetPriceRouter",
      WitnetProxy: "WitnetProxy",
      WitnetRandomness: "WitnetRandomness",
      WitnetRequestBoard: "WitnetRequestBoardTrustableDefault",
    },
  },
  constructorParams: {
    default: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 133000,
      ],
    },
    avalanche: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 155000,
      ],
    },
    boba: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 225000,
      ],
    },
    celo: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 114000,
      ],
    },
    conflux: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 78500,
      ],
    },
    "conflux.espace.testnet": {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 225000,
      ],
    },
    "conflux.espace.mainnet": {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 225000,
      ],
    },
    harmony: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 530000,
      ],
    },
    kcc: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 92500,
      ],
    },
    klaytn: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 105000,
      ],
    },
    metis: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 134800,
      ],
    },
    moonbeam: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 115000,
      ],
    },
    okxchain: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
        /* _reportResultGasLimit */ 145000,
      ],
    },
  },
  compilers: {
    default: {
      solc: {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
        outputSelection: {
          "*": {
            "*": ["evm.bytecode"],
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
      "boba.mainnet": {
        network_id: 288,
        host: "localhost",
        port: 9539,
        skipDryRun: true,
      },
      "boba.rinkeby": {
        network_id: 28,
        host: "localhost",
        port: 8539,
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
    harmony: {
      "harmony.testnet#0": {
        host: "localhost",
        port: 8534,
        network_id: 1666700000,
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
      "metis.rinkeby": {
        host: "localhost",
        port: 8536,
        network_id: 588,
        skipDryRun: true,
        gas: 30000000,
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
    polygon: {
      "polygon.goerli": {
        host: "localhost",
        port: 8535,
        network_id: 80001,
        skipDryRun: true,
        gasPrice: 30 * 10 ** 9,
      },
      "polygon.mainnet": {
        host: "localhost",
        port: 9535,
        network_id: 137,
        skipDryRun: true,
        gasPrice: 30 * 10 ** 9,
      },
    },
  },
}

function fromAscii (str) {
  const arr1 = []
  for (let n = 0, l = str.length; n < l; n++) {
    const hex = Number(str.charCodeAt(n)).toString(16)
    arr1.push(hex)
  }
  return "0x" + arr1.join("")
}
