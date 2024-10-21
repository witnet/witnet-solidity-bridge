module.exports = {
  default: {
    WitnetDeployer: "WitnetDeployer",
    apps: {
      WitPriceFeeds: "WitPriceFeedsUpgradable",
      WitRandomness: "WitRandomnessV21",
    },
    core: {
      WitOracle: "WitOracleTrustableDefault",
      WitOracleRadonRegistry: "WitOracleRadonRegistryUpgradableDefault",
      WitOracleRequestFactory: "WitOracleRequestFactorUpgradableDefault",
    },
    libs: {
      WitOracleDataLib: "WitOracleDataLib",
      WitOracleRadonEncodingLib: "WitOracleRadonEncodingLib",
      WitOracleResultErrorsLib: "WitOracleResultErrorsLib",
      WitPriceFeedsLib: "WitPriceFeedsLib",
    },
  },
  "polygon:amoy": {
    core: {
      WitOracleRequestFactory: "WitOracleRequestFactoryDefaultV21"
    }
  },
  base: {
    core: { WitOracle: "WitOracleTrustableOvm2", },
  },
  boba: {
    core: { WitOracle: "WitOracleTrustableOvm2", },
  },
  "conflux:core": {
    WitnetDeployer: "WitnetDeployerConfluxCore",
    core: { 
      WitOracleRequestFactory: "WitOracleRequestFactoryUpgradableConfluxCore", 
    },
  },
  mantle: {
    core: { WitOracle: "WitOracleTrustableOvm2", },
  },
  meter: {
    WitnetDeployer: "WitnetDeployerMeter",
    core: { WitOracleRequestFactory: "WitOracleRequestFactoryUpgradableConfluxCore", },
  },
  optimism: {
    core: { WitOracle: "WitOracleTrustableOvm2", },
  },
  "okx:x1": {
    core: { WitOracleRadonRegistry: "WitOracleRadonRegistryUpgradableNoSha256", },
  },
  "polygon:zkevm": {
    core: { WitOracleRadonRegistry: "WitOracleRadonRegistryUpgradableNoSha256", },
  },
  reef: {
    core: { WitOracle: "WitOracleTrustableReef", },
  },
  scroll: {
    core: { WitOracleRadonRegistry: "WitOracleRadonRegistryUpgradableNoSha256", },
  },
  "syscoin:rollux": {
    core: { WitOracle: "WitOracleTrustableOvm2", },
  },
  ten: {
    core: { WitOracle: "WitOracleTrustableObscuro", },
  },
}
