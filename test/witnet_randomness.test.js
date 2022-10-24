const WitnetRandomnessMock = artifacts.require("WitnetRandomnessMock")

const RandomnessBareMinimal = artifacts.require("RandomnessBareMinimal")

const {
  balance,
  BN,
} = require("@openzeppelin/test-helpers")

const truffleAssert = require("truffle-assertions")
const { expect, assert } = require("chai")

contract("WitnetRandomnesMock", accounts => {
  let witnet
  const deployer = accounts[0]
  const stranger = accounts[1]
  const fee = 10 ** 15
  const gasPrice = 1e9

  before(async () => {
    witnet = await WitnetRandomnessMock.new(
      2, // _mockRandomizeLatencyBlock
      fee, // _mockRandomizeFee
      { from: deployer }
    )
  })
  describe("Example: RandomnessBareMinimal", async () => {
    let myContract
    before(async () => {
      myContract = await RandomnessBareMinimal.new(
        witnet.address,
        { from: deployer }
      )
    })
    it("witnet address is accesible and valid", async () => {
      assert.equal(
        await myContract.witnet(),
        witnet.address
      )
    })
    it("initial randomness is zero", async () => {
      assert.equal(
        (await myContract.randomness()).toString(),
        "0"
      )
    })
    it("initial randomizing block is zero", async () => {
      assert.equal(
        (await myContract.latestRandomizingBlock()).toString(),
        "0"
      )
    })
    it("requesting random number with no fee, fails", async () => {
      await truffleAssert.reverts(
        myContract.requestRandomNumber(),
        "reward too low"
      )
    })
    it("requesting random number with less fee than required, fails", async () => {
      await truffleAssert.reverts(
        myContract.requestRandomNumber(
          { value: fee / 2 }
        ),
        "reward too low"
      )
    })
    let randomizingblock1
    it("requesting random number will spend only required gas and reward", async () => {
      const balanceTracker = await balance.tracker(deployer)
      const initialBalance = await balanceTracker.get()
      const tx = await myContract.requestRandomNumber({
        value: 10 ** 18,
        from: deployer,
        gasPrice,
      })
      const finalBalance = await balanceTracker.get()
      expect(
        finalBalance.eq(
          initialBalance
            .sub(new BN(fee))
            .sub(new BN(tx.receipt.gasUsed))
        ),
        "caller balance should have decreased only by required gas and reward"
      )
      randomizingblock1 = await myContract.latestRandomizingBlock()
      assert(randomizingblock1 > 0, "no randomizing block number")
    })
    it("fetching random number from unsolved randomize, fails", async () => {
      await truffleAssert.reverts(
        myContract.fetchRandomNumber(),
        "pending randomize"
      )
    })
    it("fetching random number from solved randomize, works", async () => {
      await myContract.nextBlock()
      await myContract.fetchRandomNumber()
    })
    let randomizingblock2
    it("upgrading pending randomize that requires no reward upgrade, transfers back unused funds", async () => {
      await myContract.requestRandomNumber({
        value: 10 ** 18,
        from: stranger,
        gasPrice: 10 * 10 ** 9,
      })
      randomizingblock2 = await myContract.latestRandomizingBlock()
      const balanceTracker = await balance.tracker(stranger)
      const initialBalance = await balanceTracker.get()
      const tx = await witnet.upgradeRandomizeFee(
        randomizingblock2,
        {
          value: 10 ** 18,
          from: stranger,
          gasPrice,
        }
      )
      const finalBalance = await balanceTracker.get()
      expect(
        finalBalance.eq(
          initialBalance
            .sub(new BN(tx.receipt.gasUsed))
        ),
        "caller balance should have decreased only be used gas"
      )
    })
  })
})
