module.exports = {
  default: {
    WitnetRequestBytecodes: "WitnetRequestBytecodesDefault",
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
    WitnetRequestBytecodes: "WitnetRequestBytecodesNoSha256",
  },
  "polygon.zkevm.mainnet": {
    WitnetRequestBytecodes: "WitnetRequestBytecodesNoSha256",
  },
  reef: {
    WitnetRequestBoard: "WitnetRequestBoardTrustableReef",
  },
  scroll: {
    WitnetRequestBytecodes: "WitnetRequestBytecodesNoSha256",
  },
  "syscoin.rollux.testnet": {
    WitnetRequestBoard: "WitnetRequestBoardTrustableOvm2",
  },
  ten: {
    WitnetRequestBoard: "WitnetRequestBoardTrustableObscuro",
  },
}
