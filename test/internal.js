const WBITestHelper = artifacts.require("WBITestHelper")
const WBI = artifacts.require("WitnetBridgeInterface")
const BlockRelay = artifacts.require("BlockRelay")
const data = require("./data.json")
const testdata = require("./internals.json")

contract("WBITestHelper - internals", accounts => {
  describe("WBI underlying algorithms: ", () => {
    let wbiInstance
    let blockRelay
    let helper
    before(async () => {
      blockRelay = await BlockRelay.deployed()
      wbiInstance = await WBI.new(blockRelay.address)
      helper = await WBITestHelper.new(wbiInstance.address)
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
    for (let [index, test] of testdata.poe.valid.entries()) {
      it(`valid poe (${index + 1})`, async () => {
        helper.lastBeacon = testdata.poe.lastBeacon
        const publicKey = [testdata.poe.publicKey.x, testdata.poe.publicKey.y]
        const proofBytes = testdata.poe.proof
        const proof = await helper.decodeProof(proofBytes)
        const fastVerifyParams = await helper.computeFastVerifyParams(publicKey, proof, testdata.poe.lastBeacon)
        await helper.setActiveIdentities(test.abs)
        console.log(helper.gammaToHash(_poe[0], _poe[1]))


        const result = await helper._verifyPoe.call(
          proof,
          publicKey,
          fastVerifyParams[0],
          fastVerifyParams[1])
        assert.equal(result, true)
      })
    }
  })
})
