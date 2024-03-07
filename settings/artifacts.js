module.exports = {
  default: {
    WitnetOracle: "WitnetOracleTrustableDefault",
    WitnetPriceFeeds: "WitnetPriceFeedsDefault",
    WitnetRequestBytecodes: "WitnetRequestBytecodesDefault",
    WitnetRequestFactory: "WitnetRequestFactoryDefault",
    WitnetEncodingLib: "WitnetEncodingLib",
    WitnetErrorsLib: "WitnetErrorsLib",
    WitnetPriceFeedsLib: "WitnetPriceFeedsLib",
    WitnetOracleDataLib: "WitnetOracleDataLib",
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
