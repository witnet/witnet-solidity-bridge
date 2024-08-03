module.exports = {
  default: {
    WitnetDeployer: "WitnetDeployer",
    WitnetOracle: "WitnetOracleTrustableDefault",
    WitnetPriceFeeds: "WitPriceFeedsV21",
    WitnetRandomness: "WitRandomnessV21",
    WitnetRadonRegistry: "WitnetRadonRegistryDefault",
    WitnetRequestFactory: "WitnetRequestFactoryDefault",
    WitnetEncodingLib: "WitnetEncodingLib",
    WitnetErrorsLib: "WitnetErrorsLib",
    WitnetPriceFeedsLib: "WitnetPriceFeedsLib",
    WitnetOracleDataLib: "WitnetOracleDataLib",
  },
  base: {
    WitnetOracle: "WitnetOracleTrustableOvm2",
  },
  boba: {
    WitnetOracle: "WitnetOracleTrustableOvm2",
  },
  "conflux:core:testnet": {
    WitnetDeployer: "WitnetDeployerCfxCore",
    WitnetRequestFactory: "WitnetRequestFactoryCfxCore",
  },
  "conflux:core:mainnet": {
    WitnetDeployer: "WitnetDeployerCfxCore",
    WitnetRequestFactory: "WitnetRequestFactoryCfxCore",
  },
  mantle: {
    WitnetOracle: "WitnetOracleTrustableOvm2",
  },
  meter: {
    WitnetDeployer: "WitnetDeployerMeter",
    WitnetRequestFactory: "WitnetRequestFactoryCfxCore",
  },
  optimism: {
    WitnetOracle: "WitnetOracleTrustableOvm2",
  },
  "okx:x1:mainnet": {
    WitnetRadonRegistry: "WitnetRadonRegistryNoSha256",
  },
  "okx:x1:sepolia": {
    WitnetRadonRegistry: "WitnetRadonRegistryNoSha256",
  },
  "polygon:zkevm:goerli": {
    WitnetRadonRegistry: "WitnetRadonRegistryNoSha256",
  },
  "polygon:zkevm:mainnet": {
    WitnetRadonRegistry: "WitnetRadonRegistryNoSha256",
  },
  reef: {
    WitnetOracle: "WitnetOracleTrustableReef",
  },
  scroll: {
    WitnetRadonRegistry: "WitnetRadonRegistryNoSha256",
  },
  "syscoin:rollux:testnet": {
    WitnetOracle: "WitnetOracleTrustableOvm2",
  },
  "syscoin:rollux:mainnet": {
    WitnetOracle: "WitnetOracleTrustableOvm2",
  },
  ten: {
    WitnetOracle: "WitnetOracleTrustableObscuro",
  },
}
