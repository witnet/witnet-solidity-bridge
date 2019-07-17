const WBITestHelper = artifacts.require("WBITestHelper")
const WBI = artifacts.require("WitnetBridgeInterface")
const BlockRelay = artifacts.require("BlockRelay")
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
    for (let [index, test] of testdata.poi.valid.entries()) {
      it(`poi (${index + 1})`, async () => {
        const poi = test.poi
        const root = test.root
        const index = test.index
        const element = test.element
        const result = await helper._verifyPoi.call(poi, root, index, element)
        assert(result)
      })
    }
    for (let [index, test] of testdata.poi.invalid.entries()) {
      it(`poi (${index + 1})`, async () => {
        const poi = test.poi
        const root = test.root
        const index = test.index
        const element = test.element
        const result = await helper._verifyPoi.call(poi, root, index, element)
        assert.notEqual(result, true)
      })
    }
  })
})
