const truffleAssert = require("truffle-assertions")
const WitnetRequestsBoardV1 = artifacts.require("WitnetRequestsBoardV1")
const WitnetRequestsBoardV2 = artifacts.require("WitnetRequestsBoardV2")
const WitnetRequestsBoardProxy = artifacts.require("WitnetRequestsBoardProxy")
const MockBlockRelay = artifacts.require("MockBlockRelay")

contract("Witnet Requests Board Proxy", accounts => {
  describe("Witnet Requests Board Proxy test suite", () => {
    let blockRelay
    let wrbInstance1
    let wrbInstance2
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
      wrbProxy = await WitnetRequestsBoardProxy.new(wrbInstance1.address, {
        from: accounts[0],
      })
    })

    it("should revert when trying to upgrade the same WRB", async () => {
      // It should revert because the WRB to be upgrated is already in use
      await truffleAssert.reverts(wrbProxy.upgradeWitnetRequestsBoard(wrbInstance1.address),
        "The provided Witnet Requests Board instance address is already in use")
    })

    it("should post a data request and read the result", async () => {
      // Take current balance
      const drBytes = web3.utils.fromAscii("This is a DR")

      const halfEther = web3.utils.toWei("0.5", "ether")

      // Post first data request
      const tx1 = wrbProxy.postDataRequest(drBytes, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })

      assert.equal(tx1, tx1)
    })

    it("should revert when trying to verify dr in blockRelayInstance", async () => {
      // Set the wrbIntance2 to be the WRB in the proxy contract
      await wrbProxy.upgradeWitnetRequestsBoard(wrbInstance2.address)
      // It should revert when trying to upgrade the wrb since wrbInstance2 is not upgradable
      await truffleAssert.reverts(wrbProxy.upgradeWitnetRequestsBoard(wrbInstance1.address),
        "The upgrade has been rejected by the current implementation")
    })
  })
})
