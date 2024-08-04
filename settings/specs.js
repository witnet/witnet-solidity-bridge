module.exports = {
  default: {
    WitOracle: {
      immutables: {
        types: ["uint256", "uint256", "uint256", "uint256"],
        values: [
          /* _reportResultGasBase */ 58282,
          /* _reportResultWithCallbackGasBase */ 65273,
          /* _reportResultWithCallbackRevertGasBase */ 69546,
          /* _sstoreFromZeroGas */ 20000,
        ],
      },
      libs: ["WitOracleResultErrorsLib", "WitOracleDataLib"],
      vanity: 13710368043, // 0x77703aE126B971c9946d562F41Dd47071dA00777
    },
    WitPriceFeeds: {
      from: "0xF121b71715E71DDeD592F1125a06D4ED06F0694D",
      libs: ["WitPriceFeedsLib"],
      vanity: 1865150170, // 0x1111AbA2164AcdC6D291b08DfB374280035E1111
    },
    WitRandomness: {
      from: "0xF121b71715E71DDeD592F1125a06D4ED06F0694D",
      vanity: 1060132513, // 0xC0FFEE98AD1434aCbDB894BbB752e138c1006fAB
    },
    WitOracleRadonRegistry: {
      libs: ["WitOracleRadonEncodingLib"],
      vanity: 6765579443, // 0x000B61Fe075F545fd37767f40391658275900000
    },
    WitOracleRequestFactory: {
      vanity: 1240014136, // 0x000DB36997AF1F02209A6F995883B9B699900000
    },
  },
  "conflux:core:mainnet": {
    WitnetDeployer: {
      from: "0x1169bf81ecf738d02fd8d3824dfe02153b334ef7",
    },
    WitOracle: {
      vanity: 3,
    },
    WitPriceFeeds: {
      from: "0x1169bf81ecf738d02fd8d3824dfe02153b334ef7",
      vanity: 4,
    },
    WitRandomness: {
      from: "0x1169bf81ecf738d02fd8d3824dfe02153b334ef7",
      vanity: 5,
    },
    WitOracleRadonRegistry: {
      vanity: 1,
    },
    WitOracleRequestFactory: {
      vanity: 2,
    },
  },
  "conflux:core:testnet": {
    WitnetDeployer: {
      from: "0x1169Bf81ecf738d02fd8d3824dfe02153B334eF7",
    },
    WitOracle: {
      vanity: 3,
    },
    WitPriceFeeds: {
      from: "0x1169Bf81ecf738d02fd8d3824dfe02153B334eF7",
      vanity: 4,
    },
    WitRandomness: {
      from: "0x1169Bf81ecf738d02fd8d3824dfe02153B334eF7",
      vanity: 5,
    },
    WitOracleRadonRegistry: {
      vanity: 1,
    },
    WitOracleRequestFactory: {
      vanity: 2,
    },
  },
  meter: {
    WitnetDeployer: {
      from: "0xE169Bf81Ecf738d02fD8d3824DFe02153b334eF7",
    },
    WitPriceFeeds: {
      from: "0xE169Bf81Ecf738d02fD8d3824DFe02153b334eF7",
    },
    WitRandomness: {
      from: "0xE169Bf81Ecf738d02fD8d3824DFe02153b334eF7",
    },
  },
  reef: {
    WitnetDeployer: {
      from: "0xB309D64D6535E95eDBA9A899A8a8D11f1BEC9357",
    },
    WitPriceFeeds: {
      from: "0xB309D64D6535E95eDBA9A899A8a8D11f1BEC9357",
    },
    WitOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ "0x3100A1CAC7EF19DC",
        ],
      },
    },
    WitRandomness: {
      from: "0xB309D64D6535E95eDBA9A899A8a8D11f1BEC9357",
    },
  },
}
