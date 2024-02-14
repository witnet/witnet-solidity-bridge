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
      vanity: 3648098779, // 0x00000eBcBDD5B6A1B4f102b165ED2C4d8B6B1000
    },
    WitnetPriceFeeds: {
      from: "0xF121b71715E71DDeD592F1125a06D4ED06F0694D",
      libs: ["WitnetPriceFeedsLib"],
      vanity: 7089974217, // 0x000080d4d4896c2c5959883430495AD58436E000
    },
    WitnetRequestBytecodes: {
      libs: ["WitnetEncodingLib"],
      vanity: 2561527884, // 0x0000B677d4a6d20C3B087c52A36E4Bed558De000
    },
    WitnetRequestFactory: {
      vanity: 7945530998, // 0x0000f7Eb1d08E68C361b8A0c4a36f442c58f1000
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
