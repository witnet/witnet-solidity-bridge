const UsingWitnet = artifacts.require("UsingWitnet")
const WBI = artifacts.require("WitnetBridgeInterface")
const BlockRelay = artifacts.require("BlockRelay")
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
      usingWitnet = await UsingWitnet.deployed()
    })

    it("create a data request and post it in the wbi (call)", async () => {
      let stringDr = "DataRequest Example"
      let expectedId = "0x" + sha.sha256(stringDr)
      let id0 = await usingWitnet.witnetPostDataRequest.call(web3.utils.utf8ToHex(stringDr), 30, {
        from: accounts[0],
        value: 100,
      })
      assert.equal(web3.utils.toHex(id0), expectedId)
    })

    it("create a data request and post it in the wbi", async () => {
      let stringDr = "DataRequest Example"
      let expectedId = "0x" + sha.sha256(stringDr)
      let actualBalance = await web3.eth.getBalance(accounts[0])

      let tx0 = usingWitnet.witnetPostDataRequest(web3.utils.utf8ToHex(stringDr), 30, {
        from: accounts[0],
        value: 100,
      })

      const txHash0 = await waitForHash(tx0)
      let txReceipt0 = await web3.eth.getTransactionReceipt(txHash0)
      let id0 = txReceipt0.logs[0].data
      assert.equal(id0, expectedId)
      let readDrBytes = await wbi.readDataRequest.call(id0)
      assert.equal(readDrBytes, web3.utils.utf8ToHex(stringDr))

      let drInfo = await wbi.requests(expectedId)
      let inclusionReward = drInfo.inclusionReward
      let tallyReward = drInfo.tallieReward
      assert.equal("70", inclusionReward.toString())
      assert.equal("30", tallyReward.toString())

      let afterBalance = await web3.eth.getBalance(accounts[0])
      assert(afterBalance < actualBalance)

      let usingWitnetBalance = await web3.eth.getBalance(usingWitnet.address)
      assert.equal(0, usingWitnetBalance)

      let wbiBalance = await web3.eth.getBalance(wbi.address)
      assert.equal(100, wbiBalance)
    })

    it("upgrade Data Request", async () => {
      let stringDr = "DataRequest Example"
      let expectedId = "0x" + sha.sha256(stringDr)
      let actualBalance = await web3.eth.getBalance(accounts[0])
      let readDrBytes = await wbi.readDataRequest.call(expectedId)
      assert.equal(readDrBytes, web3.utils.utf8ToHex(stringDr))
      let tx1 = usingWitnet.witnetUpgradeDataRequest(expectedId, 30, {
        from: accounts[0],
        value: 100,
      })

      await waitForHash(tx1)
      let drInfo = await wbi.requests(expectedId)
      let inclusionReward = drInfo.inclusionReward
      let tallyReward = drInfo.tallieReward
      assert.equal("140", inclusionReward.toString())
      assert.equal("60", tallyReward.toString())

      let afterBalance = await web3.eth.getBalance(accounts[0])
      assert(afterBalance < actualBalance)

      let usingWitnetBalance = await web3.eth.getBalance(usingWitnet.address)
      assert.equal(0, usingWitnetBalance)

      let wbiBalance = await web3.eth.getBalance(wbi.address)
      assert.equal(200, wbiBalance)
    })

    it("read Data Request result", async () => {
      let stringDr = "DataRequest Example"
      let expectedId = "0x" + sha.sha256(stringDr)
      let expectedBlockHash = 0x123456
      let drRootHash = 0x654321
      let tallyRootHash = 0x112233
      let dummySybling = 1
      let drHashRoot = web3.utils.hexToBytes("0xe1504f07d07c513c7cd919caec111b900c893a5f9ba82c4243893132aaf087f8")
      var hash = sha.sha256.create()
      hash.update(web3.utils.hexToBytes("0xba6357c24b3b0e9274b71e480b660da3aa11cb7e7a08046f9d244f31adc69878"))
      hash.update(web3.utils.hexToBytes("0xe1504f07d07c513c7cd919caec111b900c893a5f9ba82c4243893132aaf087f8"))
      let expectedDrHash = "0x" + hash.hex()
      // Claim Data Request Inclusion
      let tx2 = wbi.claimDataRequests([expectedId], web3.utils.utf8ToHex("PoE"))
      await waitForHash(tx2)

      let drInfo2 = await wbi.requests(expectedId)
      let pkh = drInfo2.pkhClaim
      let timestamp = drInfo2.timestamp
      assert(timestamp)
      assert.equal(pkh, accounts[0])

      // Report block
      blockRelay.postNewBlock(expectedBlockHash, drRootHash, tallyRootHash, {
        from: accounts[0],
      })

      // Show PoI of Data Request Inclusion
      let tx3 = wbi.reportDataRequestInclusion(expectedId, ["0xe1504f07d07c513c7cd919caec111b900c893a5f9ba82c4243893132aaf087f8"], 1, expectedBlockHash)
      await waitForHash(tx3)
      let drInfo3 = await wbi.requests(expectedId)
      let DrHash = drInfo3.drHash
      assert.equal(expectedDrHash, web3.utils.toHex(DrHash))
      // Report result
      let tx4 = wbi.reportResult(expectedId, [dummySybling], 1,
        expectedBlockHash, web3.utils.utf8ToHex("Result"))
      await waitForHash(tx4)

      let drInfo4 = await wbi.requests(expectedId)
      let result = drInfo4.result
      assert.equal(web3.utils.utf8ToHex("Result"), result)

      let resultObtained = await usingWitnet.witnetReadResult.call(expectedId)
      assert.equal(result, resultObtained)
    })
  })
})

const waitForHash = txQ =>
  new Promise((resolve, reject) =>
    txQ.on("transactionHash", resolve).catch(reject)
  )
