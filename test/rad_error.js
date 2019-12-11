const WBI = artifacts.require("WitnetBridgeInterface")
const BlockRelay = artifacts.require("BlockRelay")
const UsingWitnetTestHelper = artifacts.require("UsingWitnetTestHelper")
const Request = artifacts.require("Request")
const Witnet = artifacts.require("Witnet")

const sha = require("js-sha256")

contract("UsingWitnet", accounts => {
  describe("UsingWitnet2 \"happy path\" test case. " +
    "This covers the life cycle of a Witnet request whose result is false.", () => {
    const requestHex = "0x02"
    const resultHex = "0xd82701"
    const block1Hash = 0x123456
    const block2Hash = 0xabcdef
    const nullHash = "0xe3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    const requestReward = 7000000000000000
    const resultReward = 3000000000000000

    let witnet, clientContract, wbi, blockRelay, request, requestId, requestHash, result

    before(async () => {
      witnet = await Witnet.deployed()
      blockRelay = await BlockRelay.deployed({
        from: accounts[0],
      })
      wbi = await WBI.deployed(blockRelay.address)
      await UsingWitnetTestHelper.link(Witnet, witnet.address)
      clientContract = await UsingWitnetTestHelper.new(wbi.address)
    })

    it("should create a Witnet request", async () => {
      // Uso Request.sol para la dr que quiero para tener el hash de requestHex
      request = await Request.new(requestHex)
      const internalBytes = await request.bytecode()
      // "droid" here stands for "data request output identifier"
      const internalDroid = (await request.id()).toString(16)
      const expectedDroid = sha.sha256(web3.utils.hexToBytes(requestHex))

      assert.equal(internalBytes, requestHex)
      assert.equal(internalDroid, expectedDroid)
    })

    it("should pass the data request to the wbi", async () => {
      // Uso Request.sol para la dr que quiero para tener el hash de requestHex
      requestId = await returnData(clientContract._witnetPostRequest(request.address, requestReward, resultReward, {
        from: accounts[0],
        value: requestReward + resultReward,
      }))
      assert.equal(requestId.toString(16), "0x0000000000000000000000000000000000000000000000000000000000000001")
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

    it("should report a block containing the result into the WBI", async () => {
      const epoch = 2
      let resultHash = sha.sha256.create()
      resultHash.update(web3.utils.hexToBytes(requestHash))
      resultHash.update(web3.utils.hexToBytes(resultHex))
      resultHash = `0x${resultHash.hex()}`

      await blockRelay.postNewBlock(block2Hash, epoch, nullHash, resultHash, { from: accounts[0] })
    })

    it("Should report the result in the WBI", async () => {
      await returnData(wbi.reportResult(requestId, [], 0, block2Hash, resultHex))
      const requestinfo = await wbi.requests(requestId)
      assert.equal(requestinfo.result, resultHex)
    })

    it("Should pull the result from the wbi back to the client contract", async () => {
      await clientContract._witnetReadResult(requestId, { from: accounts[0] })
      result = await clientContract.result()
      assert.equal(result.cborValue.buffer.data, resultHex)
    })

    it("Should detect the result is false", async () => {
      await clientContract._witnetReadResult(requestId, { from: accounts[0] })
      result = await clientContract.result()
      assert.equal(result.success, false)
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
