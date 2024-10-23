module.exports = {
  default: {
    WitOracle: {
      baseDeps: [
        "WitOracleRadonRegistry",
      ],
      baseLibs: [
        "WitOracleDataLib",
        "WitOracleResultErrorsLib",
      ],
      immutables: {
        types: ["(uint32, uint32, uint32, uint32)"],
        values: [
          [
            /* _reportResultGasBase */ 58282,
            /* _reportResultWithCallbackGasBase */ 65273,
            /* _reportResultWithCallbackRevertGasBase */ 69546,
            /* _sstoreFromZeroGas */ 20000,
          ],
        ],
      },
      vanity: 13710368043, // 0x77703aE126B971c9946d562F41Dd47071dA00777
    },
    WitOracleTrustless: {
      immutables: {
        types: ["uint256", "uint256"],
        values: [
          /* _evmQueryAwaitingBlocks */ 16,
          /* _evmQueryReportingStake */ "1000000000000000000",
        ],
      },
    },
    WitOracleRadonRegistry: {
      baseLibs: [
        "WitOracleRadonEncodingLib",
      ],
      vanity: 6765579443, // 0x000B61Fe075F545fd37767f40391658275900000
    },
    WitOracleRequestFactory: {
      baseDeps: [
        "WitOracle",
      ],
      vanity: 1240014136, // 0x000DB36997AF1F02209A6F995883B9B699900000
    },
    WitPriceFeeds: {
      baseLibs: [
        "WitPriceFeedsLib",
      ],
      from: "0xF121b71715E71DDeD592F1125a06D4ED06F0694D",
      vanity: 1865150170, // 0x1111AbA2164AcdC6D291b08DfB374280035E1111
    },
    WitRandomnessV2: {
      vanity: 1060132513, // 0xC0FFEE98AD1434aCbDB894BbB752e138c1006fAB
    },
    WitRandomnessV21: {
      vanity: 127210,     // 0xFfd88EFa76a7ee79BAE373798A10AD617dD5eCFf
    }
  },
  reef: {
    WitOracle: {
      immutables: {
        values: [
          /* _reportResultGasBase */ "0x3100A1CAC7EF19DC",
        ],
      },
    },
  },
}
