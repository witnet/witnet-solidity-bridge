export default {
	default: {
		WitnetDeployer: "WitnetDeployer",
		apps: {
			WitPriceFeeds: "WitPriceFeedsV3Upgradable",
			WitPriceFeedsLegacy: "WitPriceFeedsLegacyUpgradableBypass",
			WitRandomness: "WitRandomnessV3",
		},
		core: {
			WitOracle: "WitOracleTrustableDefault",
			WitOracleRadonRegistry: "WitOracleRadonRegistryUpgradableDefault",
			WitOracleRadonRequestFactory: "WitOracleRadonRequestFactoryUpgradableDefault",
			WitOracleRadonRequestFactoryModals: "WitOracleRadonRequestFactoryModalsDefault",
			WitOracleRadonRequestFactoryTemplates: "WitOracleRadonRequestFactoryTemplatesDefault",
		},
		libs: {
			WitOracleDataLib: "WitOracleDataLib",
			WitOracleRadonEncodingLib: "WitOracleRadonEncodingLib",
			WitOracleResultStatusLib: "WitOracleResultStatusLib",
			WitPriceFeedsDataLib: "WitPriceFeedsDataLib",
			WitPriceFeedsLegacyDataLib: "WitPriceFeedsLegacyDataLib",
		},
	},
	base: {
		core: { WitOracle: "WitOracleTrustableOvm2" },
	},
	boba: {
		core: { WitOracle: "WitOracleTrustableOvm2" },
	},
	"conflux:core": {
		WitnetDeployer: "WitnetDeployerConfluxCore",
		core: {
			WitOracleRadonRequestFactory: "WitOracleRadonRequestFactoryUpgradableConfluxCore",
		},
	},
	"conflux:core:testnet": {
		core: { WitOracle: "WitOraclePushOnlyTrustableDefault" },
	},
	"conflux:espace:testnet": {
		core: { WitOracle: "WitOraclePushOnlyTrustableDefault" },
	},
	"kcc:testnet": {
		core: { WitOracle: "WitOraclePushOnlyTrustableDefault" },
	},
	mantle: {
		core: { WitOracle: "WitOracleTrustableOvm2" },
	},
	"mantle:sepolia": {
		core: { WitOracle: "WitOraclePushOnlyTrustableDefault" },
	},
	meter: {
		WitnetDeployer: "WitnetDeployerMeter",
		core: {
			WitOracleRadonRequestFactory: "WitOracleRadonRequestFactoryUpgradableConfluxCore",
		},
	},
	"moonbeam:moonbase": {
		core: { WitOracle: "WitOraclePushOnlyTrustableDefault" },
	},
	"moonbeam:moonriver": {
		core: { WitOracle: "WitOraclePushOnlyTrustableDefault" },
	},
	optimism: {
		core: { WitOracle: "WitOracleTrustableOvm2" },
	},
	"okx:x1": {
		core: {
			WitOracleRadonRegistry: "WitOracleRadonRegistryUpgradableNoSha256",
		},
	},
	"polygon:zkevm": {
		core: {
			WitOracleRadonRegistry: "WitOracleRadonRegistryUpgradableNoSha256",
		},
	},
	reef: {
		WitnetDeployer: "WitnetDeployerDeferred",
		core: { WitOracle: "WitOracleTrustableReef" },
	},
	scroll: {
		core: {
			WitOracleRadonRegistry: "WitOracleRadonRegistryUpgradableNoSha256",
		},
	},
	"syscoin:rollux": {
		core: { WitOracle: "WitOracleTrustableOvm2" },
	},
	ten: {
		WitnetDeployer: "WitnetDeployerDeferred",
		core: { WitOracle: "WitOracleTrustableObscuro" },
	},
	"unichain:sepolia": {
		core: { WitOracle: "WitOraclePushOnlyTrustableDefault" },
	},
};
