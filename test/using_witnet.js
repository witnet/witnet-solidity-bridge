const WBI = artifacts.require("WitnetBridgeInterface")
const BlockRelay = artifacts.require("BlockRelay")
const UsingWitnetTestHelper = artifacts.require("UsingWitnetTestHelper")
const Request = artifacts.require("Request")
const Witnet = artifacts.require("Witnet")

const sha = require("js-sha256")
const data = require("./data.json")

contract("UsingWitnet", accounts => {
  describe("UsingWitnet \"happy path\" test case. " +
    "This covers pretty much all the life cycle of a Witnet request.", () => {
    const requestHex = "0x00"
    const resultHex = "0x1a002fefd8"
    const resultDecimal = 3141592
    const block1Hash = 0x123456
    const block2Hash = 0xabcdef
    const nullHash = "0xe3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    const inclusionReward = 7000000000000000
    const tallyReward = 3000000000000000

    let witnet, clientContract, wbi, blockRelay, request, requestId, requestHash, result
    let lastAccount0Balance, lastAccount1Balance

    before(async () => {
      witnet = await Witnet.deployed()
      blockRelay = await BlockRelay.deployed({
        from: accounts[0],
      })
      wbi = await WBI.deployed(blockRelay.address)
      await UsingWitnetTestHelper.link(Witnet, witnet.address)
      clientContract = await UsingWitnetTestHelper.new(wbi.address)
      lastAccount0Balance = await web3.eth.getBalance(accounts[0])
      lastAccount1Balance = await web3.eth.getBalance(accounts[1])
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

    it("should post a Witnet request into the wbi", async () => {
      requestId = await returnData(clientContract._witnetPostRequest(request.address, tallyReward, {
        from: accounts[0],
        value: inclusionReward + tallyReward,
      }))
      const expectedId = "0x0000000000000000000000000000000000000000000000000000000000000000"

      assert.equal(requestId.toString(16), expectedId)
    })

    it("should have posted and read the same bytes", async () => {
      let internalBytes = await wbi.readDataRequest(requestId)
      assert.equal(internalBytes, requestHex)
    })

    it("should have set the correct rewards", async () => {
      // Retrieve rewards
      const drInfo = await wbi.requests(requestId)
      const actualInclusionReward = drInfo.inclusionReward.toString()
      const actualTallyReward = drInfo.tallyReward.toString()
      assert.equal(actualInclusionReward, inclusionReward)
      assert.equal(actualTallyReward, tallyReward)
    })

    it("requester balance should decrease", async () => {
      const afterBalance = await web3.eth.getBalance(accounts[0])
      assert(afterBalance < lastAccount0Balance)
      lastAccount0Balance = afterBalance
    })

    it("client contract balance should remain stable", async () => {
      let usingWitnetBalance = await web3.eth.getBalance(clientContract.address)
      assert.equal(usingWitnetBalance, 0)
    })

    it("WBI balance should increase", async () => {
      let wbiBalance = await web3.eth.getBalance(wbi.address)
      assert.equal(wbiBalance, inclusionReward + tallyReward)
    })

    it("should upgrade the rewards of a existing Witnet request", async () => {
      await returnData(clientContract._witnetUpgradeRequest(requestId, tallyReward, {
        from: accounts[0],
        value: inclusionReward + tallyReward,
      }))
    })

    it("should have upgraded the rewards correctly", async () => {
      // Retrieve rewards
      const drInfo = await wbi.requests(requestId)
      const actualInclusionReward = drInfo.inclusionReward.toString()
      const actualTallyReward = drInfo.tallyReward.toString()
      assert.equal(actualInclusionReward, inclusionReward * 2)
      assert.equal(actualTallyReward, tallyReward * 2)
    })

    it("requester balance should decrease after rewards upgrade", async () => {
      const afterBalance = await web3.eth.getBalance(accounts[0])
      assert(afterBalance < lastAccount0Balance - inclusionReward - tallyReward)
      lastAccount0Balance = afterBalance
    })

    it("client contract balance should remain stable after rewards upgrade", async () => {
      let usingWitnetBalance = await web3.eth.getBalance(clientContract.address)
      assert.equal(usingWitnetBalance, 0)
    })

    it("WBI balance should increase after rewards upgrade", async () => {
      let wbiBalance = await web3.eth.getBalance(wbi.address)
      assert.equal(wbiBalance, (inclusionReward + tallyReward) * 2)
    })

    it("should claim eligibility for relaying the request into Witnet", async () => {
      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const proof = await wbi.decodeProof(proofBytes)
      const message = data.poe[0].lastBeacon
      const fastVerifyParams = await wbi.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      await returnData(
        wbi.claimDataRequests([requestId], proof, publicKey, fastVerifyParams[0], fastVerifyParams[1], signature, {
          from: accounts[1],
        })
      )
    })

    it("should set a timestamp upon claiming", async () => {
      const requestInfo = await wbi.requests(requestId)
      assert(requestInfo.timestamp)
    })

    it("should set a the PKH of the claimer upon claiming", async () => {
      const requestInfo = await wbi.requests(requestId)
      assert.equal(requestInfo.pkhClaim, accounts[1])
    })

    it("should report a Witnet block containing the request into the WBI", async () => {
      const epoch = 1

      // "droid" here stands for "data request output identifier"
      const droidHex = sha.sha256(web3.utils.hexToBytes(requestHex))
      const droidBytes = web3.utils.hexToBytes(`0x${droidHex}`)
      const drRootBytes = web3.utils.hexToBytes("0xe1504f07d07c513c7cd919caec111b900c893a5f9ba82c4243893132aaf087f8")

      requestHash = sha.sha256.create()
      requestHash.update(droidBytes)
      requestHash.update(drRootBytes)
      requestHash = `0x${requestHash.hex()}`

      await returnData(blockRelay.postNewBlock(block1Hash, epoch, requestHash, nullHash, {
        from: accounts[0],
      }))
    })

    it("should prove inclusion of the request into Witnet", async () => {
      await returnData(wbi.reportDataRequestInclusion(requestId,
        ["0xe1504f07d07c513c7cd919caec111b900c893a5f9ba82c4243893132aaf087f8"],
        0,
        block1Hash), {
        from: accounts[1],
      })

      const requestInfo = await wbi.requests(requestId)
      assert.equal(`0x${requestInfo.drHash.toString(16)}`, requestHash)
    })

    it("should pay inclusion reward to the relayer", async () => {
      const afterBalance = await web3.eth.getBalance(accounts[1])
      assert(afterBalance > lastAccount1Balance + inclusionReward)
      lastAccount1Balance = afterBalance
    })

    it("should report a block containing the result into the WBI", async () => {
      const epoch = 2
      let resultHash = sha.sha256.create()
      resultHash.update(web3.utils.hexToBytes(requestHash))
      resultHash.update(web3.utils.hexToBytes(resultHex))
      resultHash = `0x${resultHash.hex()}`

      await blockRelay.postNewBlock(block2Hash, epoch, nullHash, resultHash, { from: accounts[0] })
    })

    it("should post the result of the request into the WBI", async () => {
      await returnData(wbi.reportResult(requestId, [], 0, block2Hash, resultHex))
      const requestInfo = await wbi.requests(requestId)
      assert.equal(requestInfo.result, resultHex)
    })

    it("should pull the result from the WBI back into the client contract", async () => {
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
