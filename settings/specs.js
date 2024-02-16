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
      libs: ["WitnetErrorsLib"],
      vanity: 899032812, // 0x000071F0c823bD30D2Bf4CD1E829Eba5A6070000
    },
    WitnetPriceFeeds: {
      from: "0xF121b71715E71DDeD592F1125a06D4ED06F0694D",
      libs: ["WitnetPriceFeedsLib"],
      vanity: 1865150170, // 0x1111AbA2164AcdC6D291b08DfB374280035E1111
    },
    WitnetRequestBytecodes: {
      libs: ["WitnetEncodingLib"],
      vanity: 6765579443, // 0x000B61Fe075F545fd37767f40391658275900000
    },
    WitnetRequestFactory: {
      vanity: 2294036679, // 0x000F4cCF726c5445626DBD6f2258482f61377000
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
        values: [
          /* _reportResultGasBase */ 135000,
        ],
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
