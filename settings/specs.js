export default {
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
      baseDeps: ["WitOracle"],
    },
    WitOracleRadonRequestFactoryModalsDefault: {
      vanity: 496369, // 0xff6Cf77dA52BcaC140C8777c39dB0E4A0c4D49ff
    },
    WitOracleRadonRequestFactoryTemplates: {
      baseDeps: ["WitOracle"],
    },
    WitOracleRadonRequestFactoryTemplatesDefault: {
      vanity: 166332, // 0xFFcB363e96F9cb61438ECFBb735634fef2FE43FF
    },
    WitPriceFeeds: {
      baseLibs: [
        "WitPriceFeedsDataLib",
      ],
      from: "0xF121b71715E71DDeD592F1125a06D4ED06F0694D",
      vanity: 627172870, // 0x3210564CFC8855cAD45D6d963118058fe2B80123
    },
    WitPriceFeedsLegacy: {
      baseLibs: [
        "WitPriceFeedsLegacyDataLib",
      ],
      from: "0xF121b71715E71DDeD592F1125a06D4ED06F0694D",
      vanity: 1865150170, // 0x1111AbA2164AcdC6D291b08DfB374280035E1111
    },
    WitPriceFeedsV3: {
      mutables: {
        types: ["address"],
        values: ["0xF121b71715E71DDeD592F1125a06D4ED06F0694D"]
      },
      // vanity: 0, //
    },
    WitRandomnessV2: {
      vanity: 1060132513, // 0xC0FFEE98AD1434aCbDB894BbB752e138c1006fAB
    },
    WitRandomnessV3: {
      vanity: 132246681, // 0xC0FFee84CC8a7A033B55fFc0cc6Bf3087136d391
    },
  },
  reef: {
    WitOracle: {
      immutables: {
        values: [
                /* _reportResultGasBase */ "0x3100A1CAC7EF19DC",
        ],
      },
    },
  }
};
