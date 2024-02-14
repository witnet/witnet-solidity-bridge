module.exports = {
  default: {
    WitnetOracle: "WitnetRequestBoardTrustableDefault",
    WitnetPriceFeeds: "WitnetPriceFeedsDefault",
    WitnetRequestBytecodes: "WitnetRequestBytecodesDefault",
    WitnetRequestFactory: "WitnetRequestFactoryDefault",
    WitnetEncodingLib: "WitnetEncodingLib",
    WitnetErrorsLib: "WitnetErrorsLib",
    WitnetPriceFeedsLib: "WitnetPriceFeedsLib",
  },
  boba: {
    WitnetOracle: "WitnetRequestBoardTrustableOvm2",
  },
  conflux: {
    WitnetRequestFactory: "WitnetRequestFactoryCfxCore",
  },
  mantle: {
    WitnetOracle: "WitnetRequestBoardTrustableOvm2",
  },
  optimism: {
    WitnetOracle: "WitnetRequestBoardTrustableOvm2",
  },
  "polygon.zkevm.goerli": {
    WitnetRequestBytecodes: "WitnetRequestBytecodesNoSha256",
  },
  "polygon.zkevm.mainnet": {
    WitnetRequestBytecodes: "WitnetRequestBytecodesNoSha256",
  },
  reef: {
    WitnetOracle: "WitnetOracleTrustableReef",
  },
  scroll: {
    WitnetRequestBytecodes: "WitnetRequestBytecodesNoSha256",
  },
  "syscoin.rollux.testnet": {
    WitnetOracle: "WitnetRequestBoardTrustableOvm2",
  },
  ten: {
    WitnetOracle: "WitnetRequestBoardTrustableObscuro",
  },
}
