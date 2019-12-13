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
      const expectedId = "0x" + sha.sha256("first id")
      const epoch = 1
      const drRoot = 1
      const merkleRoot = 1
      const tx1 = blockRelayInstance.postNewBlock(expectedId, epoch, drRoot, merkleRoot, {
        from: accounts[0],
      })

      await waitForHash(tx1)

      const concatenated = web3.utils.hexToBytes(expectedId).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch), 64
          )
        )
      )
      const beacon = await blockRelayInstance.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))
    })
    it("should revert when inserting the same block", async () => {
      const expectedId = "0x" + sha.sha256("first id")
      const epoch = 1
      const drRoot = 1
      const merkleRoot = 1
      await truffleAssert.reverts(blockRelayInstance.postNewBlock(expectedId, epoch, drRoot, merkleRoot, {
        from: accounts[0],
      }), "The block already existed")
    })
    it("should insert another block", async () => {
      const expectedId = "0x" + sha.sha256("second id")
      const epoch = 2
      const drRoot = 2
      const merkleRoot = 3
      const tx1 = blockRelayInstance.postNewBlock(expectedId, epoch, drRoot, merkleRoot, {
        from: accounts[0],
      })
      await waitForHash(tx1)

      const concatenated = web3.utils.hexToBytes(expectedId).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch), 64
          )
        )
      )
      const beacon = await blockRelayInstance.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))
    })
    it("should revert because an invalid address is trying to insert", async () => {
      const expectedId = "0x" + sha.sha256("third id")
      const epoch = 3
      const drRoot = 1
      const merkleRoot = 1
      await truffleAssert.reverts(blockRelayInstance.postNewBlock(expectedId, epoch, drRoot, merkleRoot, {
        from: accounts[1],
      }), "Sender not authorized")
    })
    it("should read the first blocks merkle roots", async () => {
      const expectedId = "0x" + sha.sha256("first id")
      const drRoot = await blockRelayInstance.readDrMerkleRoot.call(expectedId, {
        from: accounts[0],
      })
      const tallyRoot = await blockRelayInstance.readTallyMerkleRoot.call(expectedId, {
        from: accounts[0],
      })
      assert.equal(drRoot, 1)
      assert.equal(tallyRoot, 1)
    })
    it("should read the second blocks merkle roots", async () => {
      const expectedId = "0x" + sha.sha256("second id")
      const drRoot = await blockRelayInstance.readDrMerkleRoot.call(expectedId, {
        from: accounts[0],
      })
      const tallyRoot = await blockRelayInstance.readTallyMerkleRoot.call(expectedId, {
        from: accounts[0],
      })
      assert.equal(drRoot, 2)
      assert.equal(tallyRoot, 3)
    })
    it("should revert for trying to read from a non-existent block", async () => {
      const expectedId = "0x" + sha.sha256("forth id")
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
