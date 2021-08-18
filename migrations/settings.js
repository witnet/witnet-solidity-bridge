const packageJson = require("../package.json")
module.exports = {
  artifacts: {
    default: {
      WitnetDecoderLib: "WitnetDecoderLib",
      WitnetParserLib: "WitnetParserLib",
      WitnetProxy: "WitnetProxy",
      WitnetRequestBoard: "WitnetRequestBoardTrustableEVM",
    },
    omgx: {
      WitnetRequestBoard: "WitnetRequestBoardTrustableOVM",
    },
  },
  constructorParams: {
    default: {
      WitnetRequestBoard: [true, fromAscii(packageJson.version + "-trustable")],
    },
    omgx: {
      WitnetRequestBoard: [
        true, // _isUpgradable
        fromAscii(packageJson.version + "-trustable-boba"), // _versionTag
        15000000, // _l2GasPrice
        "0x4200000000000000000000000000000000000006", // _OVM_ETH
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
    omgx: {
      solc: {
        version: "./node_modules/@eth-optimism/solc",
      },
    },
  },
  networks: {
    default: {
      "ethereum.ropsten": {
        network_id: 3,
        host: "localhost",
        port: 8543,
      },
      "ethereum.rinkeby": {
        network_id: 4,
        host: "localhost",
        port: 8544,
        skipDryRun: true,
      },
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
    },
    conflux: {
      "conflux.testnet": {
        host: "localhost",
        port: 8540,
        network_id: 1,
        gasPrice: 10,
        skipDryRun: true,
      },
      "conflux.mainnet": {
        host: "localhost",
        port: 9540,
        network_id: 1029,
        gasPrice: 1,
        skipDryRun: true,
      },
    },
    omgx: {
      test: {
        network_id: 28,
        host: "localhost",
        port: 7545,
        networkCheckTimeout: 1000,
        gasPrice: 15000000,
        gasLimit: 150000000,
      },
      "omgx.rinkeby": {
        network_id: 28,
        host: "localhost",
        port: 8539,
        gasPrice: 15000000,
        gas: 150000000,
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
