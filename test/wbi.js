const WBI = artifacts.require("WitnetBridgeInterface")
const truffleAssert = require("truffle-assertions")

var wait = ms => new Promise((resolve, reject) => setTimeout(resolve, ms))

contract("WBI", accounts => {
  describe("WBI test suite", () => {
    let wbiInstance
    beforeEach(async () => {
      wbiInstance = await WBI.new()
    })

    it("should allow post and read drs", async () => {
      // Take current balance
      var account1 = accounts[0]
      let actualBalance1 = await web3.eth.getBalance(account1)

      const drBytes = web3.utils.fromAscii("This is a DR")
      const drBytes2 = web3.utils.fromAscii("This is a second DR")

      const tx = wbiInstance.post_dr(drBytes, {
        from: account1,
        value: web3.utils.toWei("1", "ether"),
      })
      await waitForHash(tx)
      const tx2 = wbiInstance.post_dr(drBytes2)
      await waitForHash(tx2)

      let readDrBytes = await wbiInstance.read_dr.call(0)
      let readDrBytes2 = await wbiInstance.read_dr.call(1)

      let afterBalance1 = await web3.eth.getBalance(account1)
      let contractBalanceAfter = await web3.eth.getBalance(
        wbiInstance.address
      )

      assert(afterBalance1 < actualBalance1)
      assert.equal(web3.utils.toWei("1", "ether"), contractBalanceAfter)

      assert.equal(drBytes, readDrBytes)
      assert.equal(drBytes2, readDrBytes2)
    })

    it("should allow post and read result", async () => {
      var account1 = accounts[0]
      var account2 = accounts[1]
      let actualBalance1 = await web3.eth.getBalance(account1)
      let actualBalance2 = await web3.eth.getBalance(account2)

      const drBytes = web3.utils.fromAscii("This is a DR")
      const resBytes = web3.utils.fromAscii("This is a result")

      const tx = wbiInstance.post_dr(drBytes, {
        from: account1,
        value: web3.utils.toWei("1", "ether"),
      })
      await waitForHash(tx)

      // report result
      let restx = wbiInstance.report_result(0, resBytes, { from: account2 })
      await waitForHash(restx)

      let afterBalance1 = await web3.eth.getBalance(account1)
      let afterBalance2 = await web3.eth.getBalance(account2)
      let contractBalanceAfter = await web3.eth.getBalance(
        wbiInstance.address
      )
      assert(afterBalance1 < actualBalance1)
      assert(afterBalance2 > actualBalance2)
      assert.equal(0, contractBalanceAfter)

      let readResBytes = await wbiInstance.read_result.call(0)
      assert.equal(resBytes, readResBytes)
    })

    it("should return the data request id", async () => {
      const drBytes1 = web3.utils.fromAscii("This is a DR")
      const drBytes2 = web3.utils.fromAscii("This is a second DR")

      const tx1 = wbiInstance.post_dr(drBytes1, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      let data1 = txReceipt1.logs[0].data
      assert.equal(data1, 0)

      const tx2 = wbiInstance.post_dr(drBytes2)
      const txHash2 = await waitForHash(tx2)
      let txReceipt2 = await web3.eth.getTransactionReceipt(txHash2)
      let data2 = txReceipt2.logs[0].data
      assert.equal(data2, 1)

      let readDrBytes1 = await wbiInstance.read_dr.call(data1)
      let readDrBytes2 = await wbiInstance.read_dr.call(data2)
      assert.equal(drBytes1, readDrBytes1)
      assert.equal(drBytes2, readDrBytes2)
    })

    it("should emit an event with the id", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")

      const tx = await wbiInstance.post_dr(drBytes)
      truffleAssert.eventEmitted(tx, "PostDataRequest", (ev) => {
        return ev.id.toString() === "0"
      })
      let readDrBytes = await wbiInstance.read_dr.call(0)
      assert.equal(drBytes, readDrBytes)
    })

    it("should subscribe to an event, wait for its emision, and read result", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const resBytes = web3.utils.fromAscii("This is a result")

      const tx1 = wbiInstance.post_dr(drBytes, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      let txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      let data1 = txReceipt1.logs[0].data
      assert.equal(data1, 0)

      // Subscribe to PostResult event
      wbiInstance.PostResult({}, async (_error, event) => {
        let readresBytes1 = await wbiInstance.read_result.call(data1)
        assert.equal(resBytes, readresBytes1)
      })

      const tx2 = await wbiInstance.report_result(data1, resBytes)
      // wait for the async method to finish
      await wait(500)
      truffleAssert.eventEmitted(tx2, "PostResult", (ev) => {
        return ev.id.eq(web3.utils.toBN(data1))
      })
    })
  })
})

const waitForHash = txQ =>
  new Promise((resolve, reject) =>
    txQ.on("transactionHash", resolve).catch(reject)
  )
