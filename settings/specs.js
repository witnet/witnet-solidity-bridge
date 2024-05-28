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
      vanity: 1060132513, // 0xC0FFEE98AD1434aCbDB894BbB752e138c1006fAB
    },
    WitnetRequestBytecodes: {
      libs: ["WitnetEncodingLib"],
      vanity: 6765579443, // 0x000B61Fe075F545fd37767f40391658275900000
    },
    WitnetRequestFactory: {
      vanity: 1240014136, // 0x000DB36997AF1F02209A6F995883B9B699900000
    },
  },
  "conflux:core:mainnet": {
    WitnetDeployer: {
      from: "0x1169bf81ecf738d02fd8d3824dfe02153b334ef7",
    },
    WitnetOracle: {
      vanity: 3,
    },
    WitnetPriceFeeds: {
      from: "0x1169bf81ecf738d02fd8d3824dfe02153b334ef7",
      vanity: 4,
    },
    WitnetRandomness: {
      from: "0x1169bf81ecf738d02fd8d3824dfe02153b334ef7",
      vanity: 5,
    },
    WitnetRequestBytecodes: {
      vanity: 1,
    },
    WitnetRequestFactory: {
      vanity: 2,
    },
  },
  "conflux:core:testnet": {
    WitnetDeployer: {
      from: "0x1169Bf81ecf738d02fd8d3824dfe02153B334eF7",
    },
    WitnetOracle: {
      vanity: 3,
    },
    WitnetPriceFeeds: {
      from: "0x1169Bf81ecf738d02fd8d3824dfe02153B334eF7",
      vanity: 4,
    },
    WitnetRandomness: {
      from: "0x1169Bf81ecf738d02fd8d3824dfe02153B334eF7",
      vanity: 5,
    },
    WitnetRequestBytecodes: {
      vanity: 1,
    },
    WitnetRequestFactory: {
      vanity: 2,
    },
  },
  meter: {
    WitnetDeployer: {
      from: "0xE169Bf81Ecf738d02fD8d3824DFe02153b334eF7",
    },
    WitnetPriceFeeds: {
      from: "0xE169Bf81Ecf738d02fD8d3824DFe02153b334eF7",
    },
    WitnetRandomness: {
      from: "0xE169Bf81Ecf738d02fD8d3824DFe02153b334eF7",
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
}
