module.exports = {
  default: {
    WitnetOracle: {
      immutables: {
        types: ["uint256", "uint256", "uint256", "uint256"],
        values: [
          /* _reportResultGasBase */ 58282,
          /* _reportResultWithCallbackGasBase */ 65273,
          /* _reportResultWithCallbackRevertGasBase */ 69546,
          /* _sstoreFromZeroGas */ 20000,
        ],
      },
      libs: ["WitnetErrorsLib", "WitnetOracleDataLib"],
      vanity: 13710368043, // 0x77703aE126B971c9946d562F41Dd47071dA00777
    },
    WitnetPriceFeeds: {
      from: "0xF121b71715E71DDeD592F1125a06D4ED06F0694D",
      libs: ["WitnetPriceFeedsLib"],
      vanity: 1865150170, // 0x1111AbA2164AcdC6D291b08DfB374280035E1111
    },
    WitnetRandomness: {
      from: "0xF121b71715E71DDeD592F1125a06D4ED06F0694D",
      vanity: 26475657, // 0xc0ffee84FD3B533C3fA408c993F59828395319A1
    },
    WitnetRequestBytecodes: {
      libs: ["WitnetEncodingLib"],
      vanity: 6765579443, // 0x000B61Fe075F545fd37767f40391658275900000
    },
    WitnetRequestFactory: {
      vanity: 1240014136, // 0x000DB36997AF1F02209A6F995883B9B699900000
    },
  },
  avalanche: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 155000,
        ],
      },
    },
  },
  celo: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 114000,
        ],
      },
    },
  },
  conflux: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 78500,
        ],
      },
    },
  },
  "conflux.espace.testnet": {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 225000,
        ],
      },
    },
  },
  "conflux.espace.mainnet": {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 225000,
        ],
      },
    },
  },
  cronos: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 137500,
        ],
      },
    },
  },
  dogechain: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 85000,
        ],
      },
    },
  },
  harmony: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 530000,
        ],
      },
    },
  },
  hsc: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 85000,
        ],
      },
    },
  },
  kcc: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 92500,
        ],
      },
    },
  },
  klaytn: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 105000,
        ],
      },
    },
  },
  meter: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 85000,
        ],
      },
    },
  },
  metis: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 134800,
        ],
      },
    },
  },
  moonbeam: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 115000,
        ],
      },
    },
  },
  okxchain: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 145000,
        ],
      },
    },
  },
  optimism: {
    WitnetOracle: {
      immutables: {
        // values: [
        //   /* _reportResultGasBase */ 100000,
        // ],
      },
    },
  },
  reef: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ "0x3100A1CAC7EF19DC",
        ],
      },
    },
  },
  ultron: {
    WitnetOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ 83949,
        ],
      },
    },
  },
}
