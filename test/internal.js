const WBITestHelper = artifacts.require("WBITestHelper")
const WBI = artifacts.require("WitnetBridgeInterface")
const BlockRelay = artifacts.require("BlockRelay")
const testdata = require("./internals.json")

contract("WBITestHelper - internals", accounts => {
  describe("WBI underlying algorithms: ", () => {
    let wbiInstance, blockRelay, helper
    before(async () => {
      blockRelay = await BlockRelay.deployed()
      wbiInstance = await WBI.new(blockRelay.address, 2)
      helper = await WBITestHelper.new(wbiInstance.address, 2)
    })
    for (const [index, test] of testdata.poi.valid.entries()) {
      it(`poi (${index + 1})`, async () => {
        const poi = test.poi
        const root = test.root
        const index = test.index
        const element = test.element
        const result = await helper._verifyPoi.call(poi, root, index, element)
        assert(result)
      })
    }
    for (const [index, test] of testdata.poi.invalid.entries()) {
      it(`invalid poi (${index + 1})`, async () => {
        const poi = test.poi
        const root = test.root
        const index = test.index
        const element = test.element
        const result = await helper._verifyPoi.call(poi, root, index, element)
        assert.notEqual(result, true)
      })
    }
    for (const [index, test] of testdata.sig.valid.entries()) {
      it(`sig (${index + 1})`, async () => {
        const message = web3.utils.fromAscii(test.message)
        const pubKey = test.public_key
        const sig = test.signature
        const result = await helper._verifySig.call(message, pubKey, sig)
        assert.equal(result, true)
      })
    }
    for (const [index, test] of testdata.sig.invalid.entries()) {
      it(`invalid sig (${index + 1})`, async () => {
        const message = web3.utils.fromAscii(test.message)
        const pubKey = test.public_key
        const sig = test.signature
        const result = await helper._verifySig.call(message, pubKey, sig)
        assert.notEqual(result, true)
      })
    }
    for (const [index, test] of testdata.poe.valid.entries()) {
      it(`valid poe (${index + 1})`, async () => {
        const publicKey = testdata.poe.publicKey
        await helper.setActiveIdentities(test.abs)

        const result = await helper._verifyPoe.call(
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
        await helper.setActiveIdentities(test.abs)

        const result = await helper._verifyPoe.call(
          [test.vrf, 0, 0, 0],
          publicKey,
          [0, 0],
          [0, 0, 0, 0])
        assert.equal(result, false)
      })
    }
  })
})
