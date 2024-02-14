module.exports = {
  default: {
    WitnetRequestBytecodes: {
      libs: ["WitnetEncodingLib"],
      vanity: 2561527884, // 0x0000B677d4a6d20C3B087c52A36E4Bed558De000
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
      vanity: 3648098779, // 0x00000eBcBDD5B6A1B4f102b165ED2C4d8B6B1000
    },
    WitnetRequestFactory: {
      vanity: 7945530998, // 0x0000f7Eb1d08E68C361b8A0c4a36f442c58f1000
    },
    WitnetPriceFeeds: {
      from: "0xF121b71715E71DDeD592F1125a06D4ED06F0694D",
      libs: ["WitnetPriceFeedsLib"],
      vanity: 7089974217, // 0x000080d4d4896c2c5959883430495AD58436E000
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
}
