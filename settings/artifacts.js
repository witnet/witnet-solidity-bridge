module.exports = {
  default: {
    WitnetDeployer: "WitnetDeployer",
    WitOracle: "WitOracleTrustableDefault",
    WitPriceFeeds: "WitPriceFeedsV21",
    WitRandomness: "WitRandomnessV21",
    WitOracleRadonRegistry: "WitOracleRadonRegistryDefault",
    WitOracleRequestFactory: "WitOracleRequestFactoryDefault",
    WitOracleRadonEncodingLib: "WitOracleRadonEncodingLib",
    WitOracleResultErrorsLib: "WitOracleResultErrorsLib",
    WitPriceFeedsLib: "WitPriceFeedsLib",
    WitOracleDataLib: "WitOracleDataLib",
  },
  base: {
    WitOracle: "WitOracleTrustableOvm2",
  },
  boba: {
    WitOracle: "WitOracleTrustableOvm2",
  },
  "conflux:core:testnet": {
    WitnetDeployer: "WitnetDeployerCfxCore",
    WitOracleRequestFactory: "WitOracleRequestFactoryCfxCore",
  },
  "conflux:core:mainnet": {
    WitnetDeployer: "WitnetDeployerCfxCore",
    WitOracleRequestFactory: "WitOracleRequestFactoryCfxCore",
  },
  mantle: {
    WitOracle: "WitOracleTrustableOvm2",
  },
  meter: {
    WitnetDeployer: "WitnetDeployerMeter",
    WitOracleRequestFactory: "WitOracleRequestFactoryCfxCore",
  },
  optimism: {
    WitOracle: "WitOracleTrustableOvm2",
  },
  "okx:x1:mainnet": {
    WitOracleRadonRegistry: "WitOracleRadonRegistryNoSha256",
  },
  "okx:x1:sepolia": {
    WitOracleRadonRegistry: "WitOracleRadonRegistryNoSha256",
  },
  "polygon:zkevm:goerli": {
    WitOracleRadonRegistry: "WitOracleRadonRegistryNoSha256",
  },
  "polygon:zkevm:mainnet": {
    WitOracleRadonRegistry: "WitOracleRadonRegistryNoSha256",
  },
  reef: {
    WitOracle: "WitOracleTrustableReef",
  },
  scroll: {
    WitOracleRadonRegistry: "WitOracleRadonRegistryNoSha256",
  },
  "syscoin:rollux:testnet": {
    WitOracle: "WitOracleTrustableOvm2",
  },
  "syscoin:rollux:mainnet": {
    WitOracle: "WitOracleTrustableOvm2",
  },
  ten: {
    WitOracle: "WitOracleTrustableObscuro",
  },
}
