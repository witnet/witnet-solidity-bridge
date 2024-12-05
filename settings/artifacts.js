module.exports = {
  default: {
    WitnetDeployer: "WitnetDeployer",
    WitnetOracle: "WitnetOracleTrustableDefault",
    WitnetPriceFeeds: "WitnetPriceFeedsDefault",
    WitnetRandomness: "WitnetRandomnessV2",
    WitnetRequestBytecodes: "WitnetRequestBytecodesDefault",
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
    WitnetRequestBytecodes: "WitnetRequestBytecodesNoSha256",
  },
  "okx:xlayer:sepolia": {
    WitnetRequestBytecodes: "WitnetRequestBytecodesNoSha256",
  },
  "polygon:zkevm:goerli": {
    WitnetRequestBytecodes: "WitnetRequestBytecodesNoSha256",
  },
  "polygon:zkevm:mainnet": {
    WitnetRequestBytecodes: "WitnetRequestBytecodesNoSha256",
  },
  reef: {
    WitnetOracle: "WitnetOracleTrustableReef",
  },
  scroll: {
    WitnetRequestBytecodes: "WitnetRequestBytecodesNoSha256",
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
  worldchain: {
    WitnetOracle: "WitnetOracleTrustableOvm2",
  },
}
