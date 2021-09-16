const packageJson = require("../package.json")
module.exports = {
  artifacts: {
    default: {
      WitnetDecoderLib: "WitnetDecoderLib",
      WitnetParserLib: "WitnetParserLib",
      WitnetProxy: "WitnetProxy",
      WitnetRequestBoard: "WitnetRequestBoardTrustableDefault",
    },
    boba: {
      WitnetRequestBoard: "WitnetRequestBoardTrustableBoba",
    },
  },
  constructorParams: {
    default: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _verstionTag */ fromAscii(packageJson.version + "-trustable"),
      ],
    },
    boba: {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _versionTag */ fromAscii(packageJson.version + "-trustable-boba"),
        /* _l2GasPrice */ 15000000,
        /* _l2ReportResultGasLimit */ 870000,
        /* _OVM_ETH */ "0x4200000000000000000000000000000000000006",
      ],
    },
    "boba.mainnet": {
      WitnetRequestBoard: [
        /* _isUpgradable */ true,
        /* _versionTag */ fromAscii(packageJson.version + "-trustable-boba"),
        /* _l2GasPrice */ 15000000,
        /* _l2ReportResultGasLimit */ 1870000,
        /* _OVM_ETH */ "0x4200000000000000000000000000000000000006",
      ],
    },
  },
  compilers: {
    default: {
      solc: {
        version: "0.8.6",
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
    boba: {
      solc: {
        version: "./node_modules/@eth-optimism/solc",
      },
    },
    celo: {
      solc: {
        version: "0.8.7",
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
    boba: {
      "boba.mainnet": {
        network_id: 288,
        host: "localhost",
        port: 9539,
        gasPrice: 15000000,
        skipDryRun: true,
      },
      "boba.rinkeby": {
        network_id: 28,
        host: "localhost",
        port: 8539,
        gasPrice: 15000000,
        gas: 150000000,
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
    },
    conflux: {
      "conflux.testnet": {
        host: "localhost",
        port: 8540,
        network_id: 1,
        gasPrice: 10,
        skipDryRun: true,
      },
      "conflux.tethys": {
        host: "localhost",
        port: 9540,
        network_id: 1029,
        gasPrice: 1,
        skipDryRun: true,
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
