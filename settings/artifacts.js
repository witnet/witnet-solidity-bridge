export default {
  default: {
    WitnetDeployer: "WitnetDeployer",
    apps: {
      WitPriceFeeds: "WitPriceFeedsLegacyUpgradable",
      WitRandomness: "WitRandomnessV3",
      WitRandomnessLegacy: "WitRandomnessV2",
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
    core: { WitOracle: "WitOracleTrustableObscuro" },
  },
}
