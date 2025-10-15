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
      vanity: 525250, // 0xffC4147d7b973B1766FB335bC847C7288c4365ff
    },
    WitOracleRadonRequestFactoryTemplates: {
      baseDeps: ["WitOracle"],
    },
    WitOracleRadonRequestFactoryTemplatesDefault: {
      vanity: 692892, // 0xFF5ad05D038fcc04354B2fca1fb657eA345594FF
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
      vanity: 2000244871103, // 0xC0FFEE00B76e0E48b967f2963ae6190dA32a536C
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
