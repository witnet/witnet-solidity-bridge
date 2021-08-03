const packageJson = require("../package.json")
module.exports = {
  artifacts: {
    default: {
      CBOR: "CBOR",
      Witnet: "Witnet",
      WitnetProxy: "WitnetProxy",
      WitnetRequestBoard: "WitnetRequestBoardV03",
    },
    omgx: {
      WitnetRequestBoard: "WitnetRequestBoardV03L2",
    },
  },
  constructorParams: {
    default: {
      WitnetRequestBoard: [true, fromAscii(packageJson.version)],
    },
    omgx: {
      WitnetRequestBoard: [true, fromAscii(packageJson.version), 15000000],
    },
  },
  compilers: {
    default: {
      version: "0.8.6",
    },
    conflux: {
      evmVersion: "petersburg",
    },
    omgx: {
      version: "./node_modules/@eth-optimism/solc",
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
      },
      "ethereum.goerli": {
        network_id: 5,
        host: "localhost",
        port: 8545,
      },
      "ethereum.kovan": {
        network_id: 42,
        host: "localhost",
        port: 8542,
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
    omgx: {
      // test: {
      //   network_id: 28,
      //   host: "localhost",
      //   port: 7545,
      //   networkCheckTimeout: 1000,
      //   gasPrice: 15000000,
      //   gasLimit: 150000000
      // },
      "omgx.rinkeby": {
        network_id: 28,
        host: "localhost",
        port: 7545,
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
