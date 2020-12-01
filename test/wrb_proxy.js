const truffleAssert = require("truffle-assertions")
const WitnetRequestsBoardV1 = artifacts.require("WitnetRequestsBoardV1")
const WitnetRequestsBoardV2 = artifacts.require("WitnetRequestsBoardV2")
const WitnetRequestsBoardV3 = artifacts.require("WitnetRequestsBoardV3")
const RequestContract = artifacts.require("Request")
const WrbProxyHelper = artifacts.require("WrbProxyTestHelper")
const MockBlockRelay = artifacts.require("MockBlockRelay")

contract("Witnet Requests Board Proxy", accounts => {
  describe("Witnet Requests Board Proxy test suite", () => {
    let blockRelay
    let wrbInstance1
    let wrbInstance2
    let wrbInstance3
    let wrbProxy

    before(async () => {
      blockRelay = await MockBlockRelay.new({
        from: accounts[0],
      })
      wrbInstance1 = await WitnetRequestsBoardV1.new(blockRelay.address, 1, {
        from: accounts[0],
      })
      wrbInstance2 = await WitnetRequestsBoardV2.new(blockRelay.address, 1, {
        from: accounts[0],
      })
      wrbInstance3 = await WitnetRequestsBoardV3.new(blockRelay.address, 1, {
        from: accounts[0],
      })
      wrbProxy = await WrbProxyHelper.new(wrbInstance1.address, {
        from: accounts[0],
      })
    })

    it("should revert when trying to upgrade the same WRB", async () => {
      // It should revert because the WRB to be upgrated is already in use
      await truffleAssert.reverts(wrbProxy.upgradeWitnetRequestsBoard(wrbInstance1.address),
        "The provided Witnet Requests Board instance address is already in use")
    })

    it("should revert when inserting id 0", async () => {
      // It should revert because of non-existent id 0
      await truffleAssert.reverts(wrbProxy.upgradeDataRequest(0, 1),
        "Non-existent controller for id 0")
    })

    it("should post a data request and update the currentLastId", async () => {
      // The data request to be posted
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await RequestContract.new(drBytes)
      const halfEther = web3.utils.toWei("0.5", "ether")

      // Post the data request through the Proxy
      const tx1 = wrbProxy.postDataRequest(request.address, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)

      // The id of the data request
      const id1 = txReceipt1.logs[txReceipt1.logs.length - 1].data

      // check the currentLastId has been updated in the Proxy when posting the data request
      assert.equal(true, await wrbProxy.checkLastId.call(id1))
    })

    it("should return the correposding controller of an id", async () => {
      // The data request to be posted
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await RequestContract.new(drBytes)
      const halfEther = web3.utils.toWei("0.5", "ether")

      // Post the data request through the Proxy
      const tx1 = wrbProxy.postDataRequest(request.address, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)

      // The id of the data request, it should be equal 2 since is the second DR
      const id1 = txReceipt1.logs[0].data
      assert.equal(id1, 2)

      // Upgrade the WRB address to wrbInstance2
      await wrbProxy.upgradeWitnetRequestsBoard(wrbInstance2.address)
      // Get the address of the wrb form id1
      const wrb = await wrbProxy.getControllerAddress.call(id1)

      // It should be equal to the address of wrbInstance1
      assert.equal(wrb, wrbInstance1.address)
      // The current wrb in the proxy should be equal to wrbInstance2
      assert.equal(await wrbProxy.getWrbAddress.call(), wrbInstance2.address)
    })

    it("should post a data request to new WRB and keep previous data request routes", async () => {
      // The data request to be posted
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await RequestContract.new(drBytes)
      const halfEther = web3.utils.toWei("0.5", "ether")

      // The id of the data request
      const id2 = await wrbProxy.postDataRequest.call(request.address, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      assert.equal(id2, 3)

      // Post the data request through the Proxy
      await waitForHash(
        wrbProxy.postDataRequest(request.address, halfEther, {
          from: accounts[0],
          value: web3.utils.toWei("1", "ether"),
        })
      )

      // It should be equal to the address of wrbInstance2
      const wrb2 = await wrbProxy.getControllerAddress.call(id2)
      assert.equal(wrb2, wrbInstance2.address)

      // It should be equal to the address of wrbInstance1
      const wrb1 = await wrbProxy.getControllerAddress.call(1)
      assert.equal(wrb1, wrbInstance1.address)
    })

    it("should post a data request to WRB and read the result", async () => {
      // The data request to be posted
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await RequestContract.new(drBytes)
      const halfEther = web3.utils.toWei("0.5", "ether")

      // The id of the data request with result "hello"
      const id2 = await wrbProxy.postDataRequest.call(request.address, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      assert.equal(id2, 4)

      // Post the data request through the Proxy
      await waitForHash(
        wrbProxy.postDataRequest(request.address, halfEther, {
          from: accounts[0],
          value: web3.utils.toWei("1", "ether"),
        })
      )

      // Read the result of the DR
      const result = await wrbProxy.readResult.call(id2)
      assert.equal(result, web3.utils.fromAscii("hello"))
    })

    it("should read the result of a dr of and old wrb", async () => {
      // Upgrade the WRB address to wrbInstance3
      await wrbProxy.upgradeWitnetRequestsBoard(wrbInstance3.address)

      // Read the result of the DR
      const result = await wrbProxy.readResult.call(4)
      assert.equal(result, web3.utils.fromAscii("hello"))
    })

    it("should revert when trying to upgrade a non upgradable WRB", async () => {
      // It should revert when trying to upgrade the wrb since wrbInstance3 is not upgradable
      await truffleAssert.reverts(wrbProxy.upgradeWitnetRequestsBoard(wrbInstance1.address),
        "The upgrade has been rejected by the current implementation")
    })
  })
})

const waitForHash = txQ =>
  new Promise((resolve, reject) =>
    txQ.on("transactionHash", resolve).catch(reject)
  )
