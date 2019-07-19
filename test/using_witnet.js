const WBI = artifacts.require("WitnetBridgeInterface")
const BlockRelay = artifacts.require("BlockRelay")
const UsingWitnetTestHelper = artifacts.require("UsingWitnetTestHelper")
const sha = require("js-sha256")

contract("Using witnet", accounts => {
  describe("Using witnet test suite", () => {
    let usingWitnet
    let wbi
    let blockRelay
    before(async () => {
      blockRelay = await BlockRelay.deployed({
        from: accounts[0],
      })
      wbi = await WBI.deployed(blockRelay.address)
      usingWitnet = await UsingWitnetTestHelper.new(wbi.address)
    })

    it("create a data request and post it in the wbi (call)", async () => {
      let stringDr = "DataRequest Example"
      let expectedId = "0x" + sha.sha256(stringDr)
      let id0 = await usingWitnet._witnetPostDataRequest.call(web3.utils.utf8ToHex(stringDr), 30, {
        from: accounts[0],
        value: 100,
      })
      assert.equal(web3.utils.toHex(id0), expectedId)
    })

    it("should create a data request, post it in the wbi and check balances afterwards", async () => {
      // Create the data request
      let stringDr = "DataRequest Example"
      let expectedId = "0x" + sha.sha256(stringDr)
      let actualBalance = await web3.eth.getBalance(accounts[0])

      let tx0 = usingWitnet._witnetPostDataRequest(web3.utils.utf8ToHex(stringDr), 30, {
        from: accounts[0],
        value: 100,
      })

      // Read the data request
      const txHash0 = await waitForHash(tx0)
      let txReceipt0 = await web3.eth.getTransactionReceipt(txHash0)
      let id0 = txReceipt0.logs[0].data
      assert.equal(id0, expectedId)
      let readDrBytes = await wbi.readDataRequest.call(id0)
      assert.equal(readDrBytes, web3.utils.utf8ToHex(stringDr))

      // Retrieve rewards
      let drInfo = await wbi.requests(expectedId)
      let inclusionReward = drInfo.inclusionReward
      let tallyReward = drInfo.tallyReward
      assert.equal("70", inclusionReward.toString())
      assert.equal("30", tallyReward.toString())

      // Assert correct balances
      let afterBalance = await web3.eth.getBalance(accounts[0])
      assert(afterBalance < actualBalance)

      let usingWitnetBalance = await web3.eth.getBalance(usingWitnet.address)
      assert.equal(0, usingWitnetBalance)

      let wbiBalance = await web3.eth.getBalance(wbi.address)
      assert.equal(100, wbiBalance)
    })

    it("should upgrade previos drs reward and check the balances", async () => {
      // Create the data request
      let stringDr = "DataRequest Example"
      let expectedId = "0x" + sha.sha256(stringDr)
      let actualBalance = await web3.eth.getBalance(accounts[0])
      let readDrBytes = await wbi.readDataRequest.call(expectedId)
      assert.equal(readDrBytes, web3.utils.utf8ToHex(stringDr))
      let tx1 = usingWitnet._witnetUpgradeDataRequest(expectedId, 30, {
        from: accounts[0],
        value: 100,
      })

      // Get rewards
      await waitForHash(tx1)
      let drInfo = await wbi.requests(expectedId)
      let inclusionReward = drInfo.inclusionReward
      let tallyReward = drInfo.tallyReward
      assert.equal("140", inclusionReward.toString())
      assert.equal("60", tallyReward.toString())

      // Assert correct balances
      let afterBalance = await web3.eth.getBalance(accounts[0])
      assert(afterBalance < actualBalance)

      let usingWitnetBalance = await web3.eth.getBalance(usingWitnet.address)
      assert.equal(0, usingWitnetBalance)

      let wbiBalance = await web3.eth.getBalance(wbi.address)
      assert.equal(200, wbiBalance)
    })

    it("should post data request, claim a data request," +
       "report a block return inclusion of data request and result (valid PoIs)" +
       "and read the result",
    async () => {
      // Generate necessary hashes
      let stringDr = "DataRequest Example"
      let stringRes = "Result"
      let expectedId = "0x" + sha.sha256(stringDr)
      let expectedBlockHash = 0x123456
      let drHashRoot = web3.utils.hexToBytes("0xe1504f07d07c513c7cd919caec111b900c893a5f9ba82c4243893132aaf087f8")
      var hash = sha.sha256.create()
      hash.update(web3.utils.hexToBytes(expectedId))
      hash.update(drHashRoot)
      let expectedDrHash = "0x" + hash.hex()
      hash = sha.sha256.create()
      hash.update(web3.utils.hexToBytes(expectedDrHash))
      hash.update(web3.utils.hexToBytes(web3.utils.utf8ToHex(stringRes)))
      var expectedResHash = "0x" + hash.hex()
      const epoch = 1

      // Claim Data Request Inclusion
      let tx2 = wbi.claimDataRequests([expectedId], web3.utils.utf8ToHex("PoE"))
      await waitForHash(tx2)

      let drInfo2 = await wbi.requests(expectedId)
      let pkh = drInfo2.pkhClaim
      let timestamp = drInfo2.timestamp
      assert(timestamp)
      assert.equal(pkh, accounts[0])

      // Report block
      blockRelay.postNewBlock(expectedBlockHash, epoch, expectedDrHash, expectedResHash, {
        from: accounts[0],
      })

      // Show PoI of Data Request Inclusion
      let tx3 = wbi.reportDataRequestInclusion(expectedId,
        ["0xe1504f07d07c513c7cd919caec111b900c893a5f9ba82c4243893132aaf087f8"],
        0,
        expectedBlockHash)
      await waitForHash(tx3)
      let drInfo3 = await wbi.requests(expectedId)
      let DrHash = drInfo3.drHash
      assert.equal(expectedDrHash, web3.utils.toHex(DrHash))
      // Report result
      let tx4 = wbi.reportResult(expectedId, [], 0,
        expectedBlockHash, web3.utils.utf8ToHex(stringRes))
      await waitForHash(tx4)

      let drInfo4 = await wbi.requests(expectedId)
      let result = drInfo4.result
      assert.equal(web3.utils.utf8ToHex("Result"), result)

      let resultObtained = await usingWitnet._witnetReadResult.call(expectedId)
      assert.equal(result, resultObtained)
    })
  })
})

const waitForHash = txQ =>
  new Promise((resolve, reject) =>
    txQ.on("transactionHash", resolve).catch(reject)
  )
