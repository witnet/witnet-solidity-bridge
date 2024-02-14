module.exports = {
  default: {
    WitnetBytecodes: "WitnetBytecodesDefault",
    WitnetEncodingLib: "WitnetEncodingLib",
    WitnetErrorsLib: "WitnetErrorsLib",
    WitnetPriceFeeds: "WitnetPriceFeedsDefault",
    WitnetPriceFeedsLib: "WitnetPriceFeedsLib",
    WitnetRandomness: "WitnetRandomness",
    WitnetRequestBoard: "WitnetRequestBoardTrustableDefault",
    WitnetRequestFactory: "WitnetRequestFactoryDefault",
  },
  boba: {
    WitnetRequestBoard: "WitnetRequestBoardTrustableOvm2",
  },
  conflux: {
    WitnetRequestFactory: "WitnetRequestFactoryCfxCore",
  },
  mantle: {
    WitnetRequestBoard: "WitnetRequestBoardTrustableOvm2",
  },
  optimism: {
    WitnetRequestBoard: "WitnetRequestBoardTrustableOvm2",
  },
  "polygon.zkevm.goerli": {
    WitnetBytecodes: "WitnetBytecodesNoSha256",
  },
  "polygon.zkevm.mainnet": {
    WitnetBytecodes: "WitnetBytecodesNoSha256",
  },
  reef: {
    WitnetRequestBoard: "WitnetRequestBoardTrustableReef",
  },
  scroll: {
    WitnetBytecodes: "WitnetBytecodesNoSha256",
  },
  "syscoin.rollux.testnet": {
    WitnetRequestBoard: "WitnetRequestBoardTrustableOvm2",
  },
  ten: {
    WitnetRequestBoard: "WitnetRequestBoardTrustableObscuro",
  }
}
