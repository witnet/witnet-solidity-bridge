export default {
	default: {
		WitOracle: {
			baseDeps: ["WitOracleRadonRegistry"],
			baseLibs: ["WitOracleDataLib", "WitOracleResultStatusLib"],
			vanity: 13710368043, // 0x77703aE126B971c9946d562F41Dd47071dA00777
		},
		WitOracleTrustable: {
			immutables: {
				types: ["(uint32, uint32, uint32, uint32)"],
				values: [
					[
						/* _reportResultGasBase */ 58282, /* _reportResultWithCallbackGasBase */ 65273,
						/* _reportResultWithCallbackRevertGasBase */ 69546, /* _sstoreFromZeroGas */ 20000,
					],
				],
			},
		},
		WitOracleTrustless: {
			baseLibs: ["WitOracleTrustlessDataLib"],
			immutables: {
				types: ["(uint32, uint32, uint32, uint32)", "uint256", "uint256"],
				values: [
					[
						/* _reportResultGasBase */ 58282, /* _reportResultWithCallbackGasBase */ 65273,
						/* _reportResultWithCallbackRevertGasBase */ 69546, /* _sstoreFromZeroGas */ 20000,
					],
					/* _evmQueryAwaitingBlocks */ 16, 
					/* _evmQueryReportingStake */ "1000000000000000000"
				],
			},
		},
		WitOracleRadonRegistry: {
			baseLibs: ["WitOracleRadonEncodingLib"],
			vanity: 6765579443, // 0x000B61Fe075F545fd37767f40391658275900000
		},
		WitOracleRadonRequestFactory: {
			baseDeps: ["WitOracleRadonRequestFactoryModals", "WitOracleRadonRequestFactoryTemplates"],
			vanity: 260368098, // 0x000FF9f888B1415Da64cc985f775380a94b40000
		},
		WitOracleRadonRequestFactoryModals: {
			baseDeps: ["WitOracle"],
		},
		WitOracleRadonRequestFactoryModalsDefault: {
			vanity: 655348, // 0xff0c2aAB49afE9358D6364C8d7b1Aa21853808ff
		},
		WitOracleRadonRequestFactoryTemplates: {
			baseDeps: ["WitOracle"],
		},
		WitOracleRadonRequestFactoryTemplatesDefault: {
			vanity: 1136326, // 0xFF507f5c0B1732C64688fc2921636e794041eaFF
		},
		WitPriceFeeds: {
			baseLibs: ["WitPriceFeedsDataLib"],
			vanity: 627172870, // 0x3210564CFC8855cAD45D6d963118058fe2B80123
		},
		WitPriceFeedsLegacy: {
			baseLibs: ["WitPriceFeedsLegacyDataLib"],
			vanity: 1865150170, // 0x1111AbA2164AcdC6D291b08DfB374280035E1111
		},
		WitPriceFeedsLegacyUpgradableBypass: {
			baseDeps: ["WitPriceFeeds"],
		},
		WitRandomnessV2: {
			vanity: 1060132513, // 0xC0FFEE98AD1434aCbDB894BbB752e138c1006fAB
		},
		WitRandomnessV3: {
			vanity: 1000004944751, // 0xC0FFeE9596C504Cf357E2A6038863A59Ee5E550A
		},
	},
	reef: {
		WitOracle: {
			immutables: {
				values: [/* _reportResultGasBase */ "0x3100A1CAC7EF19DC"],
			},
		},
	},
};
