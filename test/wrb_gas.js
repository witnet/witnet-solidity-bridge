const {
  BN,
  expectEvent,
  expectRevert,
  balance,
  ether,
} = require("@openzeppelin/test-helpers")
const { expect } = require("chai")

// Contracts
const WRB = artifacts.require("WitnetRequestBoard")

const Request = artifacts.require("Request")

// Request definition
const requestId = new BN(1)
// eslint-disable-next-line no-multi-str
const requestHex = "0x0abb0108bd8cb8fa05123b122468747470733a2f2f7777772e6269747374616d702e6e65742f6170692f7469636b65722\
f1a13841877821864646c6173748218571903e8185b125c123168747470733a2f2f6170692e636f696e6465736b2e636f6d2f76312f6270692f6375\
7272656e7470726963652e6a736f6e1a2786187782186663627069821866635553448218646a726174655f666c6f61748218571903e8185b1a0d0a0\
908051205fa3fc00000100322090a0508051201011003100a1804200128\
46308094ebdc03"
const resultHex = "0x1a000702c8"
const drHash = "0x0000000000000000000000000000000000000000000000000000000000000001"

contract("WitnetRequestBoard", ([
  requestor,
  claimer,
  owner,
  committeeMember,
  other,
]) => {
  beforeEach(async () => {
    this.WitnetRequestBoard = await WRB.new([owner, committeeMember], {
      from: owner,
    })
    this.Request = await Request.new(requestHex, { from: requestor })
  })

  describe("deployments", async () => {
    it("deploys WitnetRequestBoard successfully", async () => {
      expect(this.WitnetRequestBoard.address != null)
    })
  })

  describe("post data request", async () => {
    it("creator can post a data request", async () => {
      // Initial balance
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
      const contractInitialBalance = await contractBalanceTracker.get()

      // Post Data Request
      const postDataRequestTx = await this.WitnetRequestBoard.postDataRequest(
        this.Request.address,
        ether("0"),
        ether("1"), {
          from: requestor,
          value: ether("1"),
        })

      // Check `PostedRequest` event
      expectEvent(
        postDataRequestTx,
        "PostedRequest",
        {
          _from: requestor,
          _id: requestId,
        })
      expect(postDataRequestTx.logs[0].args._from, "match address of DR creator").to.be.equal(requestor)
      expect(postDataRequestTx.logs[0].args._id, "match data request id").to.be.bignumber.equal(requestId)

      // Check contract balance (increased by rewards)
      const contractFinalBalance = await contractBalanceTracker.get()
      expect(
        contractFinalBalance.eq(contractInitialBalance
          .add(ether("1"))
        ),
        "contract balance should have increase after the request creation by 1 eth",
      ).to.equal(true)
    })
    it("fails if creator is not covering DR rewards", async () => {
      // Transaction value < rewards
      await expectRevert(
        this.WitnetRequestBoard.postDataRequest(
          this.Request.address,
          ether("0"),
          ether("0"), {
            from: requestor,
            value: ether("0"),
            gasPrice: 1,
          }
        ),
        "Result reward should cover gas expenses. Check the estimateGasCost method."
      )
    })
    it("fails if creator is not covering DR result report gas cost", async () => {
      // Tally reward < MAX_REPORT_RESULT_GAS
      await expectRevert(
        this.WitnetRequestBoard.postDataRequest(
          this.Request.address,
          ether("0"),
          new BN("1"), {
            from: requestor,
            value: new BN("1"),
            gasPrice: 1,
          }
        ),
        "Result reward should cover gas expenses. Check the estimateGasCost"
      )
    })
  })

  describe("read data request gas price", async () => {
    beforeEach(async () => {
      await this.WitnetRequestBoard.postDataRequest(
        this.Request.address,
        ether("0"),
        ether("1"), {
          from: requestor,
          value: ether("1"),
          gasPrice: 1,
        }
      )
    })
    it("anyone can read data request gas price", async () => {
      // Read data request gas price from WitnetRequestBoard by `requestId`
      const gasPrice = await this.WitnetRequestBoard.readGasPrice.call(requestId, { from: other })
      expect(
        gasPrice.eq(new BN("1")),
        "data request gas price should have been set to 1 wei",
      ).to.equal(true)
    })
  })

  describe("upgrade data request", async () => {
    beforeEach(async () => {
      await this.WitnetRequestBoard.postDataRequest(
        this.Request.address,
        ether("0"),
        ether("1"), {
          from: requestor,
          value: ether("1"),
          gasPrice: 2,
        }
      )
    })
    it("creator can upgrade existing data request (1 eth for rewards)", async () => {
      // Initial balance
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
      const contractInitialBalance = await contractBalanceTracker.get()

      // Update data request (increased rewards)
      await this.WitnetRequestBoard.upgradeDataRequest(requestId, ether("0"), ether("1"), {
        from: requestor,
        value: ether("1"),
        gasPrice: 3,
      })

      // Check contract balance (increased by rewards)
      const contractFinalBalance = await contractBalanceTracker.get()
      expect(
        contractFinalBalance.eq(contractInitialBalance
          .add(ether("1"))
        ),
        "contract balance should have increased after request upgrade by 1 eth",
      ).to.equal(true)
    })
    it("creator can upgrade existing data request gas price", async () => {
      // Update data request (increased rewards)
      await this.WitnetRequestBoard.upgradeDataRequest(requestId, ether("0"), ether("1"), {
        from: requestor,
        value: ether("1"),
        gasPrice: 3,
      })

      // Read data request gas price from WitnetRequestBoard by `requestId`
      const gasPrice = await this.WitnetRequestBoard.readGasPrice.call(requestId, { from: other })

      // Check that gas price has been updated to 3 wei
      expect(
        gasPrice.eq(new BN("3")),
        "data request gas price should have been set to 3 wei",
      ).to.equal(true)
    })
    it("creator cannot decrease existing data request gas price", async () => {
      // Update data request (increased rewards)
      await this.WitnetRequestBoard.upgradeDataRequest(requestId, ether("0"), ether("1"), {
        from: requestor,
        value: ether("1"),
        gasPrice: 1,
      })

      // Read data request gas price from WitnetRequestBoard by `requestId`
      const gasPrice = await this.WitnetRequestBoard.readGasPrice.call(requestId, { from: other })

      // Check that gas price has not been updated to 1 wei
      expect(
        gasPrice.eq(new BN("2")),
        "data request gas price should not have been set to 1 wei",
      ).to.equal(true)
    })
    it("fails if creator is not covering DR result report gas cost", async () => {
      const gasPrice = ether("0.000005")
      const postResultGas = await this.WitnetRequestBoard.MAX_REPORT_RESULT_GAS.call()

      // Multiply by gas price and substract the already existing value to the limit
      const maxResultInvalidReward = (postResultGas.mul(gasPrice)).sub(ether("0.5")).sub(new BN("1"))

      // Transaction value < rewards
      await expectRevert(
        this.WitnetRequestBoard.upgradeDataRequest(requestId, 0, maxResultInvalidReward, {
          from: requestor,
          value: ether("1"),
          gasPrice: gasPrice,
        }),
        "Result reward should cover gas expenses. Check the estimateGasCost"
      )
    })
  })

  describe("report data request result", async () => {
    beforeEach(async () => {
      // Post data request
      await this.WitnetRequestBoard.postDataRequest(this.Request.address, ether("0"), ether("1"), {
        from: requestor,
        value: ether("1"),
        gasPrice: 1,
      })
    })
    it("fails if reporter is not a committee member", async () => {
      await expectRevert(
        this.WitnetRequestBoard.reportResult(requestId, drHash, resultHex, {
          from: other,
          gasPrice: 1,
        }),
        "Sender not authorized"
      )
    })
    it("committee members can report a request result from Witnet and it should receive the tallyReward", async () => {
      // Initial balances
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
      const ownerBalanceTracker = await balance.tracker(owner)
      const contractInitialBalance = await contractBalanceTracker.get()
      const ownerInitialBalance = await ownerBalanceTracker.get()

      // Report data request result from Witnet to WitnetRequestBoard
      const reportResultTx = await this.WitnetRequestBoard.reportResult(
        requestId, drHash, resultHex,
        { from: owner, gasPrice: 1 }
      )

      // Check `PostedRequest` event
      expectEvent(
        reportResultTx,
        "PostedResult",
        {
          _from: owner,
          _id: requestId,
        },
      )
      expect(reportResultTx.logs[0].args._from, "match address of DR creator").to.be.equal(owner)
      expect(reportResultTx.logs[0].args._id, "match data request id").to.be.bignumber.equal(requestId)

      // Check balances (contract decreased and claimer increased)
      const contractFinalBalance = await contractBalanceTracker.get()
      const ownerFinalBalance = await ownerBalanceTracker.get()

      expect(
        contractFinalBalance.eq(contractInitialBalance
          .sub(ether("1"))
        ),
        "contract balance should have decreased after reporting dr request result by 1 eth",
      ).to.equal(true)
      expect(
        ownerFinalBalance.eq(ownerInitialBalance
          .add(ether("1")).sub(new BN(reportResultTx.receipt.gasUsed))
        ),
        "Owner balance should have increased after reporting result",
      ).to.equal(true)
    })
  })

  describe("read data request result", async () => {
    beforeEach(async () => {
      // Post data request
      await this.WitnetRequestBoard.postDataRequest(this.Request.address, ether("0"), ether("1"), {
        from: requestor,
        value: ether("1"),
      })
      // Report data request result from Witnet to WitnetRequestBoard
      await this.WitnetRequestBoard.reportResult(requestId, drHash, resultHex, {
        from: committeeMember,
        gasPrice: 1,
      })
    })
    it("anyone can read the data request result", async () => {
      // Read data request result from WitnetRequestBoard by `requestId`
      const requestResultCall = await this.WitnetRequestBoard.readResult(requestId, { from: requestor })
      expect(requestResultCall).to.be.equal(resultHex)
    })
  })
})
