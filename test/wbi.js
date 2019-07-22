const WBI = artifacts.require("WitnetBridgeInterface")
const BlockRelay = artifacts.require("BlockRelay")
const truffleAssert = require("truffle-assertions")
const sha = require("js-sha256")

var wait = ms => new Promise((resolve, reject) => setTimeout(resolve, ms))

function calculateRoots (drBytes, resBytes) {
  var hash = sha.sha256.create()
  hash.update(web3.utils.hexToBytes(drBytes))
  var drHash = "0x" + hash.hex()
  hash = sha.sha256.create()
  hash.update(web3.utils.hexToBytes(drHash))
  hash.update(web3.utils.hexToBytes(drHash))
  let expectedDrHash = "0x" + hash.hex()
  hash = sha.sha256.create()
  hash.update(web3.utils.hexToBytes(expectedDrHash))
  hash.update(web3.utils.hexToBytes(resBytes))
  let expectedResHash = "0x" + hash.hex()
  return [expectedDrHash, expectedResHash]
}

contract("WBI", accounts => {
  describe("WBI test suite", () => {
    let wbiInstance
    let blockRelay
    beforeEach(async () => {
      blockRelay = await BlockRelay.deployed()
      wbiInstance = await WBI.new(blockRelay.address)
    })

    it("should allow post and read drs", async () => {
      // Take current balance
      var account1 = accounts[0]
      let actualBalance1 = await web3.eth.getBalance(account1)

      const drBytes = web3.utils.fromAscii("This is a DR")
      const drBytes2 = web3.utils.fromAscii("This is a second DR")

      const halfEther = web3.utils.toWei("0.5", "ether")

      const tx1 = wbiInstance.postDataRequest(drBytes, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      const tx2 = wbiInstance.postDataRequest(drBytes2, 0)
      const txHash2 = await waitForHash(tx2)
      let txReceipt2 = await web3.eth.getTransactionReceipt(txHash2)
      const id2 = txReceipt2.logs[0].data

      let readDrBytes = await wbiInstance.readDataRequest.call(id1)
      let readDrBytes2 = await wbiInstance.readDataRequest.call(id2)

      let afterBalance1 = await web3.eth.getBalance(account1)
      let contractBalanceAfter = await web3.eth.getBalance(
        wbiInstance.address
      )

      assert(parseInt(afterBalance1, 10) < parseInt(actualBalance1, 10))
      assert.equal(web3.utils.toWei("1", "ether"), contractBalanceAfter)

      assert.equal(drBytes, readDrBytes)
      assert.equal(drBytes2, readDrBytes2)
    })
    it("should upgrade the reward of the data request in the contract", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const halfEther = web3.utils.toWei("0.5", "ether")
      // one ether to the dr reward
      const tx1 = wbiInstance.postDataRequest(drBytes, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      let contractBalanceBefore = await web3.eth.getBalance(
        wbiInstance.address
      )
      assert.equal(web3.utils.toWei("1", "ether"), contractBalanceBefore)

      const tx2 = wbiInstance.upgradeDataRequest(id1, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      await waitForHash(tx2)

      let contractBalanceAfter = await web3.eth.getBalance(
        wbiInstance.address
      )

      assert.equal(web3.utils.toWei("2", "ether"), contractBalanceAfter)
    })

    it("should allow post and read result", async () => {
      var account1 = accounts[0]
      var account2 = accounts[1]
      var blockHeader = 1
      var drHash = 1
      var tallyHash = 1
      var dummySybling = 1
      let actualBalance1 = await web3.eth.getBalance(account1)
      let actualBalance2 = await web3.eth.getBalance(account2)

      const drBytes = web3.utils.fromAscii("This is a DR")
      const resBytes = web3.utils.fromAscii("This is a result")
      const roots = calculateRoots(drBytes, resBytes)
      const halfEther = web3.utils.toWei("0.5", "ether")

      const tx1 = wbiInstance.postDataRequest(drBytes, halfEther, {
        from: account1,
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      const tx2 = wbiInstance.claimDataRequests([id1], resBytes, {
        from: account2,
      })
      await waitForHash(tx2)

      const txRelay = blockRelay.postNewBlock(blockHeader, roots[0], roots[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay)

      const tx3 = wbiInstance.reportDataRequestInclusion(id1, [id1], 0, blockHeader, {
        from: account2,
      })

      await waitForHash(tx3)
      const afterBalance2 = await web3.eth.getBalance(account2)
      assert(parseInt(afterBalance2, 10) > parseInt(actualBalance2, 10))
      // report result
      let restx = wbiInstance.reportResult(id1, [], 0, blockHeader, resBytes, { from: account2 })
      await waitForHash(restx)

      let afterBalance1 = await web3.eth.getBalance(account1)
      let balanceFinal = await web3.eth.getBalance(account2)
      let contractBalanceAfter = await web3.eth.getBalance(
        wbiInstance.address
      )

      assert(parseInt(afterBalance1, 10) < parseInt(actualBalance1, 10))
      assert(parseInt(balanceFinal, 10) > parseInt(afterBalance2, 10))

      assert.equal(0, contractBalanceAfter)

      let readResBytes = await wbiInstance.readResult.call(id1)
      assert.equal(resBytes, readResBytes)
    })

    it("should return the data request id", async () => {
      const drBytes1 = web3.utils.fromAscii("This is a DR")
      const drBytes2 = web3.utils.fromAscii("This is a second DR")
      const halfEther = web3.utils.toWei("0.5", "ether")
      const tx1 = wbiInstance.postDataRequest(drBytes1, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data
      assert.equal(web3.utils.hexToNumberString(id1), web3.utils.hexToNumberString(sha.sha256("This is a DR")))

      const tx2 = wbiInstance.postDataRequest(drBytes2, 0)
      const txHash2 = await waitForHash(tx2)
      let txReceipt2 = await web3.eth.getTransactionReceipt(txHash2)
      let id2 = txReceipt2.logs[0].data
      assert.equal(web3.utils.hexToNumberString(id2), web3.utils.hexToNumberString(sha.sha256("This is a second DR")))

      let readDrBytes1 = await wbiInstance.readDataRequest.call(id1)
      let readDrBytes2 = await wbiInstance.readDataRequest.call(id2)
      assert.equal(drBytes1, readDrBytes1)
      assert.equal(drBytes2, readDrBytes2)
    })

    it("should emit an event with the id", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const hash = sha.sha256("This is a DR")
      const expectedResultId = web3.utils.hexToNumberString(hash)
      const tx = await wbiInstance.postDataRequest(drBytes, 0)
      truffleAssert.eventEmitted(tx, "PostedRequest", (ev) => {
        return ev[1].toString() === expectedResultId
      })
      let readDrBytes = await wbiInstance.readDataRequest.call(expectedResultId)
      assert.equal(drBytes, readDrBytes)
    })

    it("should subscribe to an event, wait for its emision, and read result", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const resBytes = web3.utils.fromAscii("This is a result")
      const halfEther = web3.utils.toWei("0.5", "ether")
      var blockHeader = 1
      var dummySybling = 1

      const tx1 = wbiInstance.postDataRequest(drBytes, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      let data1 = txReceipt1.logs[0].data
      assert.equal(web3.utils.hexToNumberString(data1), web3.utils.hexToNumberString(sha.sha256("This is a DR")))
      // Subscribe to reportResult event
      wbiInstance.PostedResult({}, async (_error, event) => {
        let readresBytes1 = await wbiInstance.readResult.call(data1)
        assert.equal(resBytes, readresBytes1)
      })

      const tx2 = wbiInstance.claimDataRequests([data1], resBytes, {
        from: accounts[1],
      })
      await waitForHash(tx2)

      const tx3 = wbiInstance.reportDataRequestInclusion(data1, [data1], 0, blockHeader, {
        from: accounts[1],
      })
      await waitForHash(tx3)

      const tx4 = await wbiInstance.reportResult(data1, [], 0, blockHeader, resBytes)
      // wait for the async method to finish
      await wait(500)
      truffleAssert.eventEmitted(tx4, "PostedResult", (ev) => {
        return ev[1].eq(web3.utils.toBN(data1))
      })
    })
    it("should revert the transacation when trying to read from a non-existent block", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const resBytes = web3.utils.fromAscii("This is a result")
      const halfEther = web3.utils.toWei("0.5", "ether")
      var fakeBlockHeader = 2
      var dummySybling = 1

      const tx1 = wbiInstance.postDataRequest(drBytes, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      let data1 = txReceipt1.logs[0].data
      assert.equal(web3.utils.hexToNumberString(data1), web3.utils.hexToNumberString(sha.sha256("This is a DR")))
      // Subscribe to reportResult event
      wbiInstance.PostedResult({}, async (_error, event) => {
        let readresBytes1 = await wbiInstance.readResult.call(data1)
        assert.equal(resBytes, readresBytes1)
      })

      const tx2 = wbiInstance.claimDataRequests([data1], resBytes, {
        from: accounts[1],
      })
      await waitForHash(tx2)
      // should fail to read blockhash from a non-existing block
      await truffleAssert.reverts(wbiInstance.reportDataRequestInclusion(data1, [dummySybling], 2, fakeBlockHeader, {
        from: accounts[1],
      }), "Non-existing block")
    })
    it("should test revert because of not sending enough value", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")

      await truffleAssert.reverts(wbiInstance.postDataRequest(drBytes, web3.utils.toWei("2", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      }), "Transaction value needs to be equal or greater than tally reward")
    })
    it("should revert not enough value in upgrade", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")

      const tx1 = wbiInstance.postDataRequest(drBytes, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      let data1 = txReceipt1.logs[0].data

      await truffleAssert.reverts(wbiInstance.upgradeDataRequest(data1, web3.utils.toWei("2", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      }), "Transaction value needs to be equal or greater than tally reward")
    })
    it("should revert because DR was already claimed", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR4")
      const resBytes = web3.utils.fromAscii("This is a result")
      const tx1 = wbiInstance.postDataRequest(drBytes, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      let data1 = txReceipt1.logs[0].data

      const tx2 = wbiInstance.claimDataRequests([data1], resBytes, {
        from: accounts[1],
      })
      await waitForHash(tx2)

      await truffleAssert.reverts(wbiInstance.claimDataRequests([data1], resBytes, {
        from: accounts[1],
      }), "One of the listed data requests was already claimed")
    })
    it("should revert because DR was already reported", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR5")
      const resBytes = web3.utils.fromAscii("This is a result")
      const roots = calculateRoots(drBytes, resBytes)
      var blockHeader = 2
      var dummySybling = 1
      const tx1 = wbiInstance.postDataRequest(drBytes, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      let data1 = txReceipt1.logs[0].data

      const tx2 = wbiInstance.claimDataRequests([data1], resBytes, {
        from: accounts[1],
      })
      await waitForHash(tx2)

      const txRelay = blockRelay.postNewBlock(blockHeader, roots[0], roots[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay)

      const tx3 = wbiInstance.reportDataRequestInclusion(data1, [data1], 0, blockHeader, {
        from: accounts[0],
      })
      await waitForHash(tx3)

      await truffleAssert.reverts(wbiInstance.reportDataRequestInclusion(data1, [dummySybling], 1, blockHeader, {
        from: accounts[1],
      }), "DR already included")
    })
    it("should revert because of reporting a result for which the DR inclusion was not reported", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR6")
      const resBytes = web3.utils.fromAscii("This is a result")
      var blockHeader = 1
      var dummySybling = 1
      const tx1 = wbiInstance.postDataRequest(drBytes, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      let data1 = txReceipt1.logs[0].data

      const tx2 = wbiInstance.claimDataRequests([data1], resBytes, {
        from: accounts[1],
      })
      await waitForHash(tx2)

      await truffleAssert.reverts(wbiInstance.reportResult(data1, [dummySybling], 1, blockHeader, resBytes, {
        from: accounts[1] }), "DR not yet included")
    })
    it("should revert because of reporting a result for which the result was already reported", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR7")
      const resBytes = web3.utils.fromAscii("This is a result")
      const roots = calculateRoots(drBytes, resBytes)

      var blockHeader = 3
      const tx1 = wbiInstance.postDataRequest(drBytes, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      let data1 = txReceipt1.logs[0].data

      const tx2 = wbiInstance.claimDataRequests([data1], resBytes, {
        from: accounts[1],
      })
      await waitForHash(tx2)
      
      const txRelay = blockRelay.postNewBlock(blockHeader, roots[0], roots[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay)

      const tx3 = wbiInstance.reportDataRequestInclusion(data1, [data1], 0, blockHeader, {
        from: accounts[0],
      })
      await waitForHash(tx3)

      const tx4 = wbiInstance.reportResult(data1, [], 0, blockHeader, resBytes, {
        from: accounts[1] })
      await waitForHash(tx4)
      await truffleAssert.reverts(wbiInstance.reportResult(data1, [], 1, blockHeader, resBytes, {
        from: accounts[1] }), "Result already included")
    })
  })
})

const waitForHash = txQ =>
  new Promise((resolve, reject) =>
    txQ.on("transactionHash", resolve).catch(reject)
  )
