const WBI = artifacts.require("WitnetBridgeInterface")
const BlockRelay = artifacts.require("BlockRelay")
const UsingWitnetBytesTestHelper = artifacts.require("UsingWitnetBytesTestHelper")

const sha = require("js-sha256")
const data = require("./data.json")

contract("UsingWitnetBytes", accounts => {
  describe("UsingWitnetBytes test suite", () => {
    let usingWitnet
    let wbi
    let blockRelay
    before(async () => {
      blockRelay = await BlockRelay.new({
        from: accounts[0],
      })
      wbi = await WBI.new(blockRelay.address, 2)
      usingWitnet = await UsingWitnetBytesTestHelper.new(wbi.address)
    })

    it("create a data request and post it in the wbi (call)", async () => {
      const stringDr = "DataRequest Example"
      const expectedId = "0x1"
      const id0 = await usingWitnet._witnetPostDataRequest.call(web3.utils.utf8ToHex(stringDr), 30, {
        from: accounts[0],
        value: 100,
      })
      assert.equal(web3.utils.toHex(id0), expectedId)
    })

    it("should create a data request, post it in the wbi and check balances afterwards", async () => {
      // Create the data request
      const stringDr = "DataRequest Example"
      const expectedId = "0x0000000000000000000000000000000000000000000000000000000000000001"
      const actualBalance = await web3.eth.getBalance(accounts[0])

      const tx0 = usingWitnet._witnetPostDataRequest(web3.utils.utf8ToHex(stringDr), 30, {
        from: accounts[0],
        value: 100,
      })

      // Read the data request
      const txHash0 = await waitForHash(tx0)
      const txReceipt0 = await web3.eth.getTransactionReceipt(txHash0)
      const id0 = txReceipt0.logs[0].data
      assert.equal(id0, expectedId)
      const readDrBytes = await wbi.readDataRequest.call(id0)
      assert.equal(readDrBytes, web3.utils.utf8ToHex(stringDr))

      // Retrieve rewards
      const drInfo = await wbi.requests(expectedId)
      const inclusionReward = drInfo.inclusionReward
      const tallyReward = drInfo.tallyReward
      assert.equal("70", inclusionReward.toString())
      assert.equal("30", tallyReward.toString())

      // Assert correct balances
      const afterBalance = await web3.eth.getBalance(accounts[0])
      assert(afterBalance < actualBalance)

      const usingWitnetBalance = await web3.eth.getBalance(usingWitnet.address)
      assert.equal(0, usingWitnetBalance)

      const wbiBalance = await web3.eth.getBalance(wbi.address)
      assert.equal(100, wbiBalance)
    })

    it("should upgrade previous drs reward and check the balances", async () => {
      // Create the data request
      const stringDr = "DataRequest Example"
      const expectedId = "0x1"
      const actualBalance = await web3.eth.getBalance(accounts[0])
      const readDrBytes = await wbi.readDataRequest.call(expectedId)
      assert.equal(readDrBytes, web3.utils.utf8ToHex(stringDr))
      const tx1 = usingWitnet._witnetUpgradeDataRequest(expectedId, 30, {
        from: accounts[0],
        value: 100,
      })

      // Get rewards
      await waitForHash(tx1)
      const drInfo = await wbi.requests(expectedId)
      const inclusionReward = drInfo.inclusionReward
      const tallyReward = drInfo.tallyReward
      assert.equal("140", inclusionReward.toString())
      assert.equal("60", tallyReward.toString())

      // Assert correct balances
      const afterBalance = await web3.eth.getBalance(accounts[0])
      assert(afterBalance < actualBalance)

      const usingWitnetBalance = await web3.eth.getBalance(usingWitnet.address)
      assert.equal(0, usingWitnetBalance)

      const wbiBalance = await web3.eth.getBalance(wbi.address)
      assert.equal(200, wbiBalance)
    })

    it("should post data request, claim a data request," +
       "report a block return inclusion of data request and result (valid PoIs)" +
       "and read the result",
    async () => {
      // Generate necessary hashes
      const stringDr = "DataRequest Example"
      const stringRes = "Result"
      const expectedId = "0x1"
      const drOutputHash = "0x" + sha.sha256(stringDr)
      const expectedBlockHash = 0x123456
      const drHashRoot = web3.utils.hexToBytes("0xe1504f07d07c513c7cd919caec111b900c893a5f9ba82c4243893132aaf087f8")
      var hash = sha.sha256.create()
      hash.update(web3.utils.hexToBytes(drOutputHash))
      hash.update(drHashRoot)
      const expectedDrHash = "0x" + hash.hex()
      hash = sha.sha256.create()
      hash.update(web3.utils.hexToBytes(expectedDrHash))
      hash.update(web3.utils.hexToBytes(web3.utils.utf8ToHex(stringRes)))
      var expectedResHash = "0x" + hash.hex()
      const epoch = 1

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const proof = await wbi.decodeProof(proofBytes)
      const message = data.poe[0].lastBeacon
      const fastVerifyParams = await wbi.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // Claim Data Request Inclusion
      const tx2 =
        wbi.claimDataRequests([expectedId], proof, publicKey, fastVerifyParams[0], fastVerifyParams[1], signature, {
          from: accounts[1],
        })
      await waitForHash(tx2)

      const drInfo2 = await wbi.requests(expectedId)
      const pkh = drInfo2.pkhClaim
      const timestamp = drInfo2.timestamp
      assert(timestamp)
      assert.equal(pkh, accounts[1])

      // Report block
      blockRelay.postNewBlock(expectedBlockHash, epoch, expectedDrHash, expectedResHash, {
        from: accounts[0],
      })

      // Show PoI of Data Request Inclusion
      const tx3 = wbi.reportDataRequestInclusion(expectedId,
        ["0xe1504f07d07c513c7cd919caec111b900c893a5f9ba82c4243893132aaf087f8"],
        0,
        expectedBlockHash)
      await waitForHash(tx3)
      const drInfo3 = await wbi.requests(expectedId)
      const DrHash = drInfo3.drHash
      assert.equal(expectedDrHash, web3.utils.toHex(DrHash))
      // Report result
      const tx4 = wbi.reportResult(expectedId, [], 0,
        expectedBlockHash, web3.utils.utf8ToHex(stringRes))
      await waitForHash(tx4)

      const drInfo4 = await wbi.requests(expectedId)
      const result = drInfo4.result
      assert.equal(web3.utils.utf8ToHex("Result"), result)

      const resultObtained = await usingWitnet._witnetReadResult.call(expectedId)
      assert.equal(result, resultObtained)
    })
  })
})

const waitForHash = txQ =>
  new Promise((resolve, reject) =>
    txQ.on("transactionHash", resolve).catch(reject)
  )
