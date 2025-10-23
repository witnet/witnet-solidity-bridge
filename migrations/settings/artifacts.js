export default {
  default: {
    WitnetDeployer: "WitnetDeployer",
    apps: {
      WitPriceFeeds: "WitPriceFeedsV3Upgradable",
      WitPriceFeedsLegacy: "WitPriceFeedsLegacyUpgradable",
      WitRandomness: "WitRandomnessV3"
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
  "ethereum:sepolia": {
    apps: {
      WitPriceFeedsLegacy: "WitPriceFeedsLegacyUpgradableBypass",
    }
  },
  mantle: {
    core: { WitOracle: "WitOracleTrustableOvm2" },
  },
  meter: {
    WitnetDeployer: "WitnetDeployerMeter",
    core: { WitOracleRadonRequestFactory: "WitOracleRadonRequestFactoryUpgradableConfluxCore" },
  },
  optimism: {
    core: { WitOracle: "WitOracleTrustableOvm2" },
  },
  "okx:x1": {
    core: { WitOracleRadonRegistry: "WitOracleRadonRegistryUpgradableNoSha256" },
  },
  "polygon:zkevm": {
    core: { WitOracleRadonRegistry: "WitOracleRadonRegistryUpgradableNoSha256" },
  },
  reef: {
    WitnetDeployer: "WitnetDeployerDeferred",
    core: { WitOracle: "WitOracleTrustableReef" },
  },
  scroll: {
    core: { WitOracleRadonRegistry: "WitOracleRadonRegistryUpgradableNoSha256" },
  },
  "syscoin:rollux": {
    core: { WitOracle: "WitOracleTrustableOvm2" },
  },
  ten: {
    WitnetDeployer: "WitnetDeployerDeferred",
    core: { WitOracle: "WitOracleTrustableObscuro" },
  },
}
