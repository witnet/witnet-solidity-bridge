module.exports = {
  default: {
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
  conflux: {
    WitnetRequestFactory: "WitnetRequestFactoryCfxCore",
  },
  mantle: {
    WitnetOracle: "WitnetOracleTrustableOvm2",
  },
  optimism: {
    WitnetOracle: "WitnetOracleTrustableOvm2",
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
  ten: {
    WitnetOracle: "WitnetOracleTrustableObscuro",
  },
}
