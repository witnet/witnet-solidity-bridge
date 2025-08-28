module.exports = {
  default: {
    WitOracle: {
      baseDeps: [
        "WitOracleRadonRegistry",
      ],
      baseLibs: [
        "WitOracleDataLib",
        "WitOracleResultStatusLib",
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
      baseLibs: [
        "WitOracleTrustlessDataLib",
      ],
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
    WitOracleRadonRequestFactory: {
      baseDeps: [
        "WitOracleRadonRequestFactoryModals",
        "WitOracleRadonRequestFactoryTemplates",
      ],
      vanity: 260368098, // 0x000FF9f888B1415Da64cc985f775380a94b40000
    },
    WitOracleRadonRequestFactoryModals: {
      baseDeps: [ "WitOracle" ],
      vanity: 2595673, // 0xff752C3722EA1A9533ba20794594F2e567ca64ff
    },
    WitOracleRadonRequestFactoryTemplates: {
      baseDeps: [ "WitOracle" ],
      vanity: 4665235, // 0xFF93344228F706aFFf49A65Ac027A50A97a94eFF
    },
    WitPriceFeeds: {
      baseLibs: [
        "WitPriceFeedsLegacyDataLib",
      ],
      from: "0xF121b71715E71DDeD592F1125a06D4ED06F0694D",
      vanity: 1865150170, // 0x1111AbA2164AcdC6D291b08DfB374280035E1111
    },
    WitRandomnessV2: {
      vanity: 1060132513, // 0xC0FFEE98AD1434aCbDB894BbB752e138c1006fAB
    },
    WitRandomnessV3: {
      vanity: 127210,
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
