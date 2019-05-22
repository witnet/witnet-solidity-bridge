const WBI = artifacts.require("WitnetBridgeInterface")

contract("WBI", accounts => {
  describe("WBI test suite", () => {
    let wbiInstance
    beforeEach(async () => {
      wbiInstance = await WBI.new()
    })

    it("should allow post and read drs", async () => {
      const waitForHash = (txQ) => new Promise((resolve, reject) => txQ.on("transactionHash", hash => resolve(hash)).catch(reject))
      // Take current balance
      var account1 = accounts[0]
      let actualBalance1 = await web3.eth.getBalance(account1)

      const drBytes = web3.utils.fromAscii("This is a DR?")
      const drBytes2 = web3.utils.fromAscii("This is a second DR?")
      let contract_balance = await web3.eth.getBalance(wbiInstance.address)

      const tx = wbiInstance.post_dr(drBytes, { from: account1, value: web3.utils.toWei("1", "ether") })
      await waitForHash(tx)
      const tx2 = wbiInstance.post_dr(drBytes2)
      await waitForHash(tx2)

      let readDrBytes = await wbiInstance.read_dr.call(0)
      let readDrBytes2 = await wbiInstance.read_dr.call(1)

      let afterBalance1 = await web3.eth.getBalance(account1)
      let contract_balance_after = await web3.eth.getBalance(wbiInstance.address)

      assert(afterBalance1 < actualBalance1)
      assert.equal(web3.utils.toWei("1", "ether"), contract_balance_after)

      assert.equal(drBytes, readDrBytes)
      assert.equal(drBytes2, readDrBytes2)
    })
    it("should allow post and read result", async () => {
      var account1 = accounts[0]
      var account2 = accounts[1]
      let actualBalance1 = await web3.eth.getBalance(account1)
      let actualBalance2 = await web3.eth.getBalance(account2)

      const waitForHash = (txQ) => new Promise((resolve, reject) => txQ.on("transactionHash", hash => resolve(hash)).catch(reject))

      const drBytes = web3.utils.fromAscii("This is a DR?")
      const resBytes = web3.utils.fromAscii("This is a result?")

      const tx = wbiInstance.post_dr(drBytes, { from: account1, value: web3.utils.toWei("1", "ether") })
      await waitForHash(tx)

      // report result
      let restx = wbiInstance.report_result(0, resBytes, { from: account2 })
      await waitForHash(restx)

      let afterBalance1 = await web3.eth.getBalance(account1)
      let afterBalance2 = await web3.eth.getBalance(account2)

      let contract_balance_after = await web3.eth.getBalance(wbiInstance.address)

      assert(afterBalance1 < actualBalance1)
      assert(afterBalance2 > actualBalance2)
      assert.equal(0, contract_balance_after)
      let readResBytes = await wbiInstance.read_result.call(0)

      assert.equal(resBytes, readResBytes)
    })
  })
})
