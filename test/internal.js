const WBITestHelper = artifacts.require("WBITestHelper")
const MockBlockRelay = artifacts.require("MockBlockRelay")
const BlockRelayProxy = artifacts.require("BlockRelayProxy")
const testdata = require("./internals.json")

contract("WBITestHelper - internals", accounts => {
  describe("WBI underlying algorithms: ", () => {
    let blockRelay
    let blockRelayProxy
    let wbiHelper
    before(async () => {
      blockRelay = await MockBlockRelay.new()
      blockRelayProxy = await BlockRelayProxy.new(blockRelay.address, {
        from: accounts[0],
      })
      wbiHelper = await WBITestHelper.new(blockRelayProxy.address, 2)
    })
    for (const [index, test] of testdata.sig.valid.entries()) {
      it(`sig (${index + 1})`, async () => {
        const message = web3.utils.fromAscii(test.message)
        const pubKey = test.public_key
        const sig = test.signature
        const result = await wbiHelper._verifySig.call(message, pubKey, sig)
        assert.equal(result, true)
      })
    }
    for (const [index, test] of testdata.sig.invalid.entries()) {
      it(`invalid sig (${index + 1})`, async () => {
        const message = web3.utils.fromAscii(test.message)
        const pubKey = test.public_key
        const sig = test.signature
        const result = await wbiHelper._verifySig.call(message, pubKey, sig)
        assert.notEqual(result, true)
      })
    }
    for (const [index, test] of testdata.poe.valid.entries()) {
      it(`valid poe (${index + 1})`, async () => {
        const publicKey = testdata.poe.publicKey
        await wbiHelper.setActiveIdentities(test.abs)

        const result = await wbiHelper._verifyPoe.call(
          [test.vrf, 0, 0, 0],
          publicKey,
          [0, 0],
          [0, 0, 0, 0])
        assert.equal(result, true)
      })
    }
    for (const [index, test] of testdata.poe.invalid.entries()) {
      it(`invalid poe (${index + 1})`, async () => {
        const publicKey = testdata.poe.publicKey
        await wbiHelper.setActiveIdentities(test.abs)

        const result = await wbiHelper._verifyPoe.call(
          [test.vrf, 0, 0, 0],
          publicKey,
          [0, 0],
          [0, 0, 0, 0])
        assert.equal(result, false)
      })
    }
  })
})
