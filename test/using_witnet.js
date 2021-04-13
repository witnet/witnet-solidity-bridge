const WRB = artifacts.require("WitnetRequestBoard")
const WRBProxy = artifacts.require("WitnetRequestBoardProxy")
const UsingWitnetTestHelper = artifacts.require("UsingWitnetTestHelper")
const Request = artifacts.require("Request")
const Witnet = artifacts.require("Witnet")

const truffleAssert = require("truffle-assertions")

const sha = require("js-sha256")

contract("UsingWitnet", accounts => {
  describe("UsingWitnet \"happy path\" test case. " +
    "This covers pretty much all the life cycle of a Witnet request.", () => {
    const requestHex = "0x01"
    const resultHex = "0x1a002fefd8"
    const resultDecimal = 3141592
    const drHash = "0xe3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    const requestReward = web3.utils.toWei("0", "ether")
    const resultReward = web3.utils.toWei("1", "ether")
    const blockReward = web3.utils.toWei("0", "ether")
    const overallReward = web3.utils.toWei("1", "ether")

    let witnet, clientContract, wrb, wrbProxy, request, requestId, result
    let lastAccount0Balance

    before(async () => {
      witnet = await Witnet.deployed()
      wrb = await WRB.new([accounts[0]])
      wrbProxy = await WRBProxy.new(wrb.address)
      await UsingWitnetTestHelper.link(Witnet, witnet.address)
      clientContract = await UsingWitnetTestHelper.new(wrbProxy.address)
      lastAccount0Balance = await web3.eth.getBalance(accounts[0])
    })

    it("should create a Witnet request", async () => {
      request = await Request.new(requestHex)
      const internalBytes = await request.bytecode()
      // "droid" here stands for "data request output identifier"
      const internalDroid = (await request.id()).toString(16)
      const expectedDroid = sha.sha256(web3.utils.hexToBytes(requestHex))

      assert.equal(internalBytes, requestHex)
      assert.equal(internalDroid, expectedDroid)
    })

    it("should post a Witnet request into the wrb", async () => {
      requestId = await returnData(clientContract._witnetPostRequest(
        request.address,
        requestReward,
        resultReward,
        blockReward,
        {
          from: accounts[1],
          value: overallReward,
        }
      ))
      const expectedId = "0x0000000000000000000000000000000000000000000000000000000000000001"

      assert.equal(requestId.toString(16), expectedId)
    })

    it("should have posted and read the same bytes", async () => {
      const internalBytes = await wrb.readDataRequest(requestId)
      assert.equal(internalBytes, requestHex)
    })

    it("should have set the correct rewards", async () => {
      // Retrieve rewards
      const drInfo = await wrb.requests(requestId)
      const actualTallyReward = drInfo.tallyReward.toString()
      assert.equal(actualTallyReward, resultReward)
    })

    it("requester balance should decrease", async () => {
      const afterBalance = await web3.eth.getBalance(accounts[0])
      assert(afterBalance < lastAccount0Balance)
      lastAccount0Balance = afterBalance
    })

    it("client contract balance should remain stable", async () => {
      const usingWitnetBalance = await web3.eth.getBalance(clientContract.address)
      assert.equal(usingWitnetBalance, 0)
    })

    it("WRB balance should increase", async () => {
      const wrbBalance = await web3.eth.getBalance(wrb.address)
      assert.equal(wrbBalance, overallReward)
    })

    it("should upgrade the rewards of an existing Witnet request", async () => {
      await returnData(clientContract._witnetUpgradeRequest(requestId, requestReward, resultReward, blockReward, {
        from: accounts[1],
        value: overallReward,
      }))
    })

    it("should have upgraded the rewards correctly", async () => {
      // Retrieve rewards
      const drInfo = await wrb.requests(requestId)
      const actualTallyReward = drInfo.tallyReward.toString()
      assert.equal(actualTallyReward, resultReward * 2)
    })

    it("requester balance should decrease after rewards upgrade", async () => {
      const afterBalance = await web3.eth.getBalance(accounts[1])
      assert(afterBalance < lastAccount0Balance - requestReward - resultReward - blockReward)
      lastAccount0Balance = afterBalance
    })

    it("client contract balance should remain stable after rewards upgrade", async () => {
      const usingWitnetBalance = await web3.eth.getBalance(clientContract.address)
      assert.equal(usingWitnetBalance, 0)
    })

    it("WRB balance should increase after rewards upgrade", async () => {
      const wrbBalance = await web3.eth.getBalance(wrb.address)
      assert.equal(wrbBalance, overallReward * 2)
    })

    it("should set a timestamp upon claiming", async () => {
      const requestInfo = await wrb.requests(requestId)
      assert(requestInfo.blockNumber)
    })

    it("should post the result of the request into the WRB", async () => {
      await returnData(wrb.reportResult(requestId, drHash, resultHex, {
        from: accounts[0],
      }))
      const requestInfo = await wrb.requests(requestId)
      assert.equal(requestInfo.result, resultHex)
    })

    it("should pull the result from the WRB back into the client contract", async () => {
      await clientContract._witnetReadResult(requestId, { from: accounts[0] })
      result = await clientContract.result()
      assert.equal(result.success, true)
      assert.equal(result.cborValue.buffer.data, resultHex)
    })

    it("should decode result successfully", async () => {
      const actualResultDecimal = await clientContract._witnetAsUint64.call()
      assert.equal(actualResultDecimal.toString(), resultDecimal.toString())
    })
  })

  describe("UsingWitnet \"happy path\" test case with a false result.", () => {
    const requestHex = "0x02"
    const resultHex = "0xd82701"
    const drHash = "0xe3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    const requestReward = web3.utils.toWei("0", "ether")
    const resultReward = web3.utils.toWei("1", "ether")
    const blockReward = web3.utils.toWei("0", "ether")
    const overallReward = web3.utils.toWei("1", "ether")

    let witnet, clientContract, wrb, request, requestId, result

    before(async () => {
      witnet = await Witnet.deployed()
      wrb = await WRB.new([accounts[0]])
      await UsingWitnetTestHelper.link(Witnet, witnet.address)
      clientContract = await UsingWitnetTestHelper.new(wrb.address)
    })

    it("should create a Witnet request", async () => {
      request = await Request.new(requestHex)
      const internalBytes = await request.bytecode()
      // "droid" here stands for "data request output identifier"
      const internalDroid = (await request.id()).toString(16)
      const expectedDroid = sha.sha256(web3.utils.hexToBytes(requestHex))

      assert.equal(internalBytes, requestHex)
      assert.equal(internalDroid, expectedDroid)
    })

    it("should pass the data request to the wrb", async () => {
      requestId = await returnData(clientContract._witnetPostRequest(
        request.address,
        requestReward,
        resultReward,
        blockReward, {
          from: accounts[1],
          value: overallReward,
        }
      ))
      assert.equal(requestId.toString(16), "0x0000000000000000000000000000000000000000000000000000000000000001")
    })

    it("Should report the result in the WRB", async () => {
      await returnData(wrb.reportResult(requestId, drHash, resultHex, {
        from: accounts[0],
      }))
      const requestinfo = await wrb.requests(requestId)
      assert.equal(requestinfo.result, resultHex)
    })

    it("Should pull the result from the WRB back to the client contract", async () => {
      await clientContract._witnetReadResult(requestId, { from: accounts[1] })
      result = await clientContract.result()
      assert.equal(result.cborValue.buffer.data, resultHex)
    })

    it("Should detect the result is false", async () => {
      await clientContract._witnetReadResult(requestId, { from: accounts[1] })
      result = await clientContract.result()
      assert.equal(result.success, false)
    })

    it("Should revert if reward amounts are smaller than transaction value", async () => {
      const requestReward = web3.utils.toWei("1", "ether")
      const resultReward = web3.utils.toWei("1", "ether")
      const blockReward = web3.utils.toWei("0", "ether")
      const transactionValue = web3.utils.toWei("3", "ether")

      await truffleAssert.reverts(
        clientContract._witnetPostRequest(request.address, requestReward, resultReward, blockReward, {
          from: accounts[1],
          value: transactionValue,
        }),
        "Transaction value should equal the sum of rewards"
      )
    })

    it("Should revert if reward amounts sum overflows", async () => {
      const resultReward = web3.utils.toBN("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")

      await truffleAssert.reverts(
        clientContract._witnetPostRequest(request.address, resultReward, 1, 1, {
          from: accounts[1],
          value: 0,
        }),
        "The sum of rewards overflows"
      )
    })

    it("Should revert if reward amounts sum overflows 2", async () => {
      const requestReward = web3.utils.toBN("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
      const blockReward = web3.utils.toBN("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")

      await truffleAssert.reverts(
        clientContract._witnetPostRequest(request.address, requestReward, 1, blockReward, {
          from: accounts[1],
          value: 0,
        }),
        "The sum of rewards overflows"
      )
    })

    it("Should be able to estimate gas cost and post the DR", async () => {
      const gasPrice = 20000
      const rewards = await clientContract._witnetEstimateGasCost.call(gasPrice)
      await truffleAssert.passes(
        clientContract._witnetPostRequest(request.address, rewards[0], rewards[1], rewards[2], {
          from: accounts[1],
          value: rewards[0].add(rewards[1].add(rewards[2])),
          gasPrice: gasPrice,
        }),
        "Estimated rewards should cover the gas costs"
      )
    })

    it("should revert if not authorized sender tries to report result")

    it("should revert if not authorized sender tries to upgrade data request reward")
  })
})

function waitForHash (tx) {
  return new Promise((resolve, reject) =>
    tx.on("transactionHash", resolve).catch(reject)
  )
}

async function returnData (tx) {
  const txHash = await waitForHash(tx)
  const txReceipt = await web3.eth.getTransactionReceipt(txHash)
  if (txReceipt.logs[0]) {
    return txReceipt.logs[0].data
  }
}
