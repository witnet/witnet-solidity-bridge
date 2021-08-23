const settings = require("../migrations/witnet.settings")

const { assert } = require("chai")
const truffleAssert = require("truffle-assertions")

const WitnetParser = artifacts.require(settings.artifacts.default.WitnetParserLib)

const WitnetRequest = artifacts.require("WitnetRequestTestHelper")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoardTestHelper")
const WrbProxyHelper = artifacts.require("WrbProxyTestHelper")
const TrojanHorseNotUpgradable = artifacts.require("WitnetRequestBoardTrojanHorseNotUpgradable")
const TrojanHorseBadProxiable = artifacts.require("WitnetRequestBoardTrojanHorseBadProxiable")

contract("Witnet Requests Board Proxy", accounts => {
  describe("Witnet Requests Board Proxy test suite:", () => {
    const contractOwner = accounts[0]
    const requestSender = accounts[1]

    let witnet
    let wrbInstance1
    let wrbInstance2
    let wrbInstance3
    let proxy
    let wrb

    before(async () => {
      witnet = await WitnetParser.deployed()
      await WitnetRequestBoard.link(WitnetParser, witnet.address)
      wrbInstance1 = await WitnetRequestBoard.new([contractOwner], true)
      wrbInstance2 = await WitnetRequestBoard.new([contractOwner], true)
      wrbInstance3 = await WitnetRequestBoard.new([contractOwner], false)
      proxy = await WrbProxyHelper.new({ from: accounts[2] })
      proxy.upgradeWitnetRequestBoard(wrbInstance1.address, { from: contractOwner })
      wrb = await WitnetRequestBoard.at(proxy.address)
    })

    it("should revert when inserting id 0", async () => {
      // It should revert because of non-existent id 0
      await truffleAssert.reverts(
        wrb.upgradeReward(0, { from: requestSender }),
        "not in Posted"
      )
    })

    it("should post a data request and update the getNextQueryId meter", async () => {
      // The data request to be posted
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await WitnetRequest.new(drBytes)

      // Post the data request through the Proxy
      const tx1 = wrb.postRequest(request.address, {
        from: requestSender,
        value: web3.utils.toWei("0.5", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)

      // The id of the data request
      const id1 = parseInt(decodeWitnetLogs(txReceipt1.logs, 0).id)
      const nextId = await wrb.getNextQueryId.call()

      // check the nextId has been updated in the Proxy when posting the data request
      assert.equal((id1 + 1).toString(), nextId.toString())
    })

    it("fails if trying to upgrade to null contract", async () => {
      await truffleAssert.reverts(
        proxy.upgradeWitnetRequestBoard("0x0000000000000000000000000000000000000000", { from: contractOwner }),
        "null implementation"
      )
    })

    it("fails if owner tries to upgrade to same implementation instance as current one", async () => {
      await truffleAssert.reverts(
        proxy.upgradeWitnetRequestBoard(await proxy.implementation.call(), { from: contractOwner }),
        "nothing to upgrade"
      )
    })

    it("fails if owner tries to upgrade to non-Initializable implementation", async () => {
      await truffleAssert.reverts(
        proxy.upgradeWitnetRequestBoard(proxy.address, { from: contractOwner }),
        ""
      )
    })

    it("fails if foreigner tries to upgrade to compliant new implementation", async () => {
      await truffleAssert.reverts(
        proxy.upgradeWitnetRequestBoard(wrbInstance2.address, { from: requestSender }),
        "not authorized"
      )
    })

    it("fails if owner tries to upgrade to not Upgradable-compliant implementation", async () => {
      const troyHorse = await TrojanHorseNotUpgradable.new()
      await truffleAssert.reverts(
        proxy.upgradeWitnetRequestBoard(troyHorse.address, { from: contractOwner }),
        "not compliant"
      )
    })

    it("fails if owner tries to upgrade to a bad Proxiable-compliant implementation", async () => {
      const troyHorse = await TrojanHorseBadProxiable.new()
      await truffleAssert.reverts(
        proxy.upgradeWitnetRequestBoard(troyHorse.address, { from: contractOwner }),
        "proxiableUUIDs mismatch"
      )
    })

    it("should upgrade proxy to compliant new implementation, if called from owner address", async () => {
      // The data request to be posted
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await WitnetRequest.new(drBytes)

      // Post the data request through the Proxy
      const tx1 = wrb.postRequest(request.address, {
        from: requestSender,
        value: web3.utils.toWei("0.5", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)

      // The id of the data request, it should be equal 2 since is the second DR
      const id1 = decodeWitnetLogs(txReceipt1.logs, 0).id
      assert.equal(id1, 2)

      // Upgrade the WRB address to wrbInstance2 (destroying wrbInstance1)
      await proxy.upgradeWitnetRequestBoard(wrbInstance2.address, { from: contractOwner })

      // The current wrb in the proxy should be equal to wrbInstance2
      assert.equal(await proxy.implementation.call(), wrbInstance2.address)
    })

    it("fails if foreigner tries to re-initialize current implementation", async () => {
      await truffleAssert.reverts(
        wrb.initialize(web3.eth.abi.encodeParameter("address[]", [requestSender]), { from: requestSender }),
        "only owner"
      )
    })

    it("fails also if the owner tries to re-initialize current implementation", async () => {
      await truffleAssert.reverts(
        wrb.initialize(web3.eth.abi.encodeParameter("address[]", [requestSender]), { from: contractOwner }),
        "already initialized"
      )
    })

    it("should post a data request to new WRB and keep previous data request routes", async () => {
      // The data request to be posted
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await WitnetRequest.new(drBytes)

      // The id of the data request
      const id2 = await wrb.postRequest.call(request.address, {
        from: requestSender,
        value: web3.utils.toWei("0.5", "ether"),
      })
      assert.equal(id2, 3)

      // Post the data request through the Proxy
      await waitForHash(
        wrb.postRequest(request.address, {
          from: requestSender,
          value: web3.utils.toWei("0.5", "ether"),
        })
      )

      // Reading previous data request (<3) should work:
      await wrb.readRequest(2)
    })

    it("should post a data request to WRB and read the result", async () => {
      // The data request to be posted
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await WitnetRequest.new(drBytes)

      // The id of the data request with result "hello"
      const id2 = await wrb.postRequest.call(request.address, {
        from: requestSender,
        value: web3.utils.toWei("0.5", "ether"),
      })
      assert.equal(id2, 4)

      // Post the data request through the Proxy
      await waitForHash(
        wrb.postRequest(request.address, {
          from: requestSender,
          value: web3.utils.toWei("0.5", "ether"),
        })
      )

      // Read the actual result of the DR
      const result = await wrb.readResponseResult.call(id2)
      assert.equal(result.value.buffer.data, web3.utils.fromAscii("hello"))
    })

    it("should read the result of a dr of an old wrb", async () => {
      // Upgrade the WRB address to wrbInstance3
      await proxy.upgradeWitnetRequestBoard(wrbInstance3.address, {
        from: contractOwner,
      })

      // Read the actual result of the DR
      const result = await wrb.readResponseResult.call(4)
      assert.equal(result.value.buffer.data, web3.utils.fromAscii("hello"))
    })

    it("a solved data request can only be deleted by actual requester", async () => {
      // Read the result of the DR just before destruction:
      const response = await wrb.deleteQuery.call(4, { from: requestSender })
      const result = await wrb.resultFromCborBytes.call(response.cborBytes)
      assert.equal(result.value.buffer.data, web3.utils.fromAscii("hello"))

      await truffleAssert.reverts(
        wrb.deleteQuery(4, { from: contractOwner }),
        "only requester"
      )
      const tx = await wrb.deleteQuery(4, { from: requestSender }) // should work
      assert.equal(tx.logs[0].args[1], requestSender)
    })

    it("fails if trying to get bytecode from deleted DRs", async () => {
      await truffleAssert.reverts(
        wrb.readRequestBytecode.call(4),
        "deleted"
      )
    })

    it("fails if trying to upgrade a non upgradable implementation", async () => {
      // It should revert when trying to upgrade the wrb since wrbInstance3 is not upgradable
      await truffleAssert.reverts(
        proxy.upgradeWitnetRequestBoard(wrbInstance1.address, { from: contractOwner }),
        "not upgradable"
      )
    })
  })
})

const waitForHash = txQ =>
  new Promise((resolve, reject) =>
    txQ.on("transactionHash", resolve).catch(reject)
  )

function decodeWitnetLogs (logs, index) {
  if (logs.length > index) {
    return web3.eth.abi.decodeLog(
      [
        {
          type: "uint256",
          name: "id",
        }, {
          type: "address",
          name: "from",
        },
      ],
      logs[index].data,
      logs[index].topcis
    )
  }
}
