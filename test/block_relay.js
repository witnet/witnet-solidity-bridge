const BlockRelay = artifacts.require("BlockRelay")
const sha = require("js-sha256")
const truffleAssert = require("truffle-assertions")

contract("Block relay", accounts => {
  describe("Block relay test suite", () => {
    let blockRelayInstance
    before(async () => {
      blockRelayInstance = await BlockRelay.new({
        from: accounts[0],
      })
    })
    it("should post a new block in the block relay", async () => {
      let expectedId = "0x" + sha.sha256("first id")
      let tx1 = blockRelayInstance.postNewBlock(expectedId, 1, 1, {
        from: accounts[0],
      })

      await waitForHash(tx1)
    })
    it("should revert when inserting the same block", async () => {
      let expectedId = "0x" + sha.sha256("first id")
      await truffleAssert.reverts(blockRelayInstance.postNewBlock(expectedId, 1, 1, {
        from: accounts[0],
      }), "The block already existed.")
    })
    it("should insert another block", async () => {
      let expectedId = "0x" + sha.sha256("second id")
      let tx1 = blockRelayInstance.postNewBlock(expectedId, 2, 3, {
        from: accounts[0],
      })
      await waitForHash(tx1)
    })
    it("should revert because an invalid address is trying to insert", async () => {
      let expectedId = "0x" + sha.sha256("third id")
      await truffleAssert.reverts(blockRelayInstance.postNewBlock(expectedId, 1, 1, {
        from: accounts[1],
      }), "Sender not authorized")
    })
    it("should read the first blocks merkle roots", async () => {
      let expectedId = "0x" + sha.sha256("first id")
      let drRoot = await blockRelayInstance.readDrMerkleRoot.call(expectedId, {
        from: accounts[0],
      })
      let tallyRoot = await blockRelayInstance.readTallyMerkleRoot.call(expectedId, {
        from: accounts[0],
      })
      assert.equal(drRoot, 1)
      assert.equal(tallyRoot, 1)
    })
    it("should read the second blocks merkle roots", async () => {
      let expectedId = "0x" + sha.sha256("second id")
      let drRoot = await blockRelayInstance.readDrMerkleRoot.call(expectedId, {
        from: accounts[0],
      })
      let tallyRoot = await blockRelayInstance.readTallyMerkleRoot.call(expectedId, {
        from: accounts[0],
      })
      assert.equal(drRoot, 2)
      assert.equal(tallyRoot, 3)
    })
    it("should revert for trying to read from a non-existent block", async () => {
      let expectedId = "0x" + sha.sha256("forth id")
      await truffleAssert.reverts(blockRelayInstance.readDrMerkleRoot(expectedId, {
        from: accounts[1],
      }), "Non-existing block")
      await truffleAssert.reverts(blockRelayInstance.readTallyMerkleRoot(expectedId, {
        from: accounts[1],
      }), "Non-existing block")
    })
  })
})

const waitForHash = txQ =>
  new Promise((resolve, reject) =>
    txQ.on("transactionHash", resolve).catch(reject)
  )
