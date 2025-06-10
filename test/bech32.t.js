const { ethers, hre } = require("hardhat")

describe("TestBech32", function () {
  
  let bech32;

  const witBytes20 = "0x28e6c01c921ec3dd2e4dedf0ba85b52dfb4fed86"

  const expectedWitMainnetPkh = "wit19rnvq8yjrmpa6tjdahct4pd49ha5lmvxuvddhv";
  const expectedWitTestnetPkh = "twit19rnvq8yjrmpa6tjdahct4pd49ha5lmvxjeyfha";

    // bytes20 public witBytes20 = hex"28e6c01c921ec3dd2e4dedf0ba85b52dfb4fed86";
    // bytes public witSignature = hex"";
    // address public evmAddress = 0x9634E8719f67b56a960B0A6C038adC437613842e;

  let witMainnetPkh, witTestnetPkh

  before(async function () {
    bech32 = await ethers.deployContract("TestBech32")
  });

  it("toBech32Mainnet()", async function () {
    witMainnetPkh = await bech32.toBech32Mainnet(witBytes20)
    console.log(witMainnetPkh)
  })

  it("toBech32Testnet()", async function() {
    witTestnetPkh = await bech32.toBech32Testnet(witBytes20)
    console.log(witTestnetPkh)
  })

  it("fromBech32Mainnet(witMainnetPkh)", async function () {
    console.log(await bech32.fromBech32Mainnet(witMainnetPkh))
  })

//   it("fromBech32Mainnet(witTestnetPkh)", async function () {
//     console.log(await bech32.fromBech32Mainnet(witTestnetPkh))
//   })

  it("fromBech32Testnet(witTestnetPkh)", async function () {
    console.log(await bech32.fromBech32Testnet(witTestnetPkh))
  })

//   it("fromBech32Testnet(witMainnetPkh)", async function () {
//     console.log(await bech32.fromBech32Testnet(witMainnetPkh))
//   })


})
