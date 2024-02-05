module.exports = {
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
}
