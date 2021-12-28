const settings = require("../migrations/witnet.settings")

const {
  BN,
  expectEvent,
  expectRevert,
  balance,
  ether,
} = require("@openzeppelin/test-helpers")
const { expect } = require("chai")

// Contracts
const WRB = artifacts.require(settings.artifacts.default.WitnetRequestBoard)

const WitnetRequest = artifacts.require("WitnetRequestTestHelper")
const WitnetRequestTestHelper = artifacts.require("WitnetRequestTestHelper")

// WitnetRequest definition
const queryId = new BN(1)
// eslint-disable-next-line no-multi-str
const requestHex = "0x0abb0108bd8cb8fa05123b122468747470733a2f2f7777772e6269747374616d702e6e65742f6170692f7469636b65722\
f1a13841877821864646c6173748218571903e8185b125c123168747470733a2f2f6170692e636f696e6465736b2e636f6d2f76312f6270692f6375\
7272656e7470726963652e6a736f6e1a2786187782186663627069821866635553448218646a726174655f666c6f61748218571903e8185b1a0d0a0\
908051205fa3fc00000100322090a0508051201011003100a1804200128\
46308094ebdc03"
const resultHex = "0x1a000702c8"
const drTxHash = "0x0000000000000000000000000000000000000000000000000000000000000001"

contract("WitnetRequestBoard", ([
  requester,
  owner,
  committeeMember,
  other,
]) => {
  beforeEach(async () => {
    this.WitnetRequestBoard = await WRB.new(
      ...settings.constructorParams.default.WitnetRequestBoard,
      { from: owner }
    )
    await this.WitnetRequestBoard.initialize(
      web3.eth.abi.encodeParameter("address[]",
        [owner, committeeMember]),
      { from: owner }
    )
    this.WitnetRequest = await WitnetRequest.new(requestHex, { from: requester })
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
      const postDataRequestTx = await this.WitnetRequestBoard.postRequest(
        this.WitnetRequest.address,
        {
          from: requester,
          value: ether("1"),
        }
      )

      // Check `PostedRequest` event
      expectEvent(
        postDataRequestTx,
        "PostedRequest",
        {
          queryId: queryId,
        }
      )
      expect(postDataRequestTx.logs[0].args.queryId, "match data request id").to.be.bignumber.equal(queryId)

      // Check contract balance (increased by reward)
      const contractFinalBalance = await contractBalanceTracker.get()
      expect(
        contractFinalBalance.eq(contractInitialBalance
          .add(ether("1"))
        ),
        "contract balance should have increase after the request creation by 1 eth",
      ).to.equal(true)
    })
    it("creator can post data requests with sequential identifiers", async () => {
      // Post Data Requests
      const postDataRequestTx1 = await this.WitnetRequestBoard.postRequest(
        this.WitnetRequest.address,
        {
          from: requester,
          value: ether("1"),
        })
      const postDataRequestTx2 = await this.WitnetRequestBoard.postRequest(
        this.WitnetRequest.address,
        {
          from: requester,
          value: ether("1"),
        })

      // Check `PostedRequest` events
      expectEvent(
        postDataRequestTx1,
        "PostedRequest",
        {
          queryId: queryId,
        })
      expect(postDataRequestTx1.logs[0].args.queryId, "match data request id").to.be.bignumber.equal(queryId)
      // Check `PostedRequest` events
      expectEvent(
        postDataRequestTx2,
        "PostedRequest",
        {
          queryId: queryId.add(new BN(1)),
        })
      expect(
        postDataRequestTx2.logs[0].args.queryId,
        "match data request id"
      ).to.be.bignumber.equal(queryId.add(new BN(1)))
    })
    it("fails if creator is not covering DR reward", async () => {
      // Transaction value < reward
      await expectRevert(
        this.WitnetRequestBoard.postRequest(
          this.WitnetRequest.address,
          {
            from: requester,
            value: ether("0"),
            gasPrice: 1,
          }
        ),
        "reward too low."
      )
    })
    it("fails if creator is not covering DR result report gas cost", async () => {
      // Tally reward < ESTIMATED_REPORT_RESULT_GAS
      await expectRevert(
        this.WitnetRequestBoard.postRequest(
          this.WitnetRequest.address,
          {
            from: requester,
            value: new BN("1"),
            gasPrice: 1,
          }
        ),
        "reward too low."
      )
    })
    it("reading bytecode from unsolved query works if the request was not modified before being solved", async () => {
      await this.WitnetRequestBoard.postRequest(this.WitnetRequest.address, { from: requester, value: ether("1") })
      assert.equal(
        await this.WitnetRequest.bytecode.call(),
        await this.WitnetRequestBoard.readRequestBytecode.call(1)
      )
    })
    it("reading bytecode from unsolved query fails if the request gets modified before being solved", async () => {
      await this.WitnetRequestBoard.postRequest(this.WitnetRequest.address, { from: requester, value: ether("1") })
      const newDrBytes = web3.utils.fromAscii("This is a different DR")
      await this.WitnetRequest.modifyBytecode(newDrBytes)
      await expectRevert(
        this.WitnetRequestBoard.readRequestBytecode.call(1),
        "bytecode changed after posting"
      )
    })
  })

  describe("upgrade data request", async () => {
    beforeEach(async () => {
      await this.WitnetRequestBoard.postRequest(
        this.WitnetRequest.address,
        {
          from: requester,
          value: ether("1"),
          gasPrice: 2,
        }
      )
    })
    it("anyone can upgrade existing data request increasing the reward", async () => {
      // Initial balance
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
      const contractInitialBalance = await contractBalanceTracker.get()

      // Update data request (increased reward)
      await this.WitnetRequestBoard.upgradeReward(queryId, {
        from: other,
        value: ether("1"),
        gasPrice: 3,
      })

      // Check contract balance (increased by reward)
      const contractFinalBalance = await contractBalanceTracker.get()
      expect(
        contractFinalBalance.eq(contractInitialBalance
          .add(ether("1"))
        ),
        "contract balance should have increased after request upgrade by 1 eth",
      ).to.equal(true)
    })
    it("anyone can upgrade existing data request gas price", async () => {
      // Update data request (increased reward)
      await this.WitnetRequestBoard.upgradeReward(queryId, {
        from: other,
        value: ether("1"),
        gasPrice: 3,
      })

      // Read data request gas price from WitnetRequestBoard by `queryId`
      const gasPrice = await this.WitnetRequestBoard.readRequestGasPrice.call(queryId, { from: other })

      // Check that gas price has been updated to 3 wei
      expect(
        gasPrice.eq(new BN("3")),
        "data request gas price should have been set to 3 wei",
      ).to.equal(true)
    })
    it("creator cannot decrease existing data request gas price", async () => {
      // Update data request (increased reward)
      await this.WitnetRequestBoard.upgradeReward(queryId, {
        from: requester,
        value: ether("1"),
        gasPrice: 1,
      })

      // Read data request gas price from WitnetRequestBoard by `queryId`
      const gasPrice = await this.WitnetRequestBoard.readRequestGasPrice.call(queryId, { from: other })

      // Check that gas price has not been updated to 1 wei
      expect(
        gasPrice.eq(new BN("2")),
        "data request gas price should not have been set to 1 wei",
      ).to.equal(true)
    })
    it("fails if anyone upgrades DR with new gas price that decreases reward below gas limit", async () => {
      // Report result reward < ESTIMATED_REPORT_RESULT_GAS * newGasPrice
      const newGasPrice = ether("0.01")
      await expectRevert(
        this.WitnetRequestBoard.upgradeReward(queryId, {
          from: requester,
          value: ether("0"),
          gasPrice: newGasPrice,
        }),
        "reward too low"
      )
    })
    it("fails if result is already reported", async () => {
      await this.WitnetRequestBoard.reportResult(
        queryId, drTxHash, resultHex,
        { from: owner, gasPrice: 1 }
      )
      // Update data request (increased reward)
      await expectRevert(
        this.WitnetRequestBoard.upgradeReward(queryId, {
          from: requester,
          value: ether("1"),
          gasPrice: 3,
        }),
        "not in Posted status"
      )
    })
  })

  describe("report data request result", async () => {
    beforeEach(async () => {
      // Post data request
      await this.WitnetRequestBoard.postRequest(this.WitnetRequest.address, {
        from: requester,
        value: ether("1"),
        gasPrice: 1,
      })
    })
    it("committee members can report a request result from Witnet and it should receive the tallyReward", async () => {
      // Initial balances
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
      const ownerBalanceTracker = await balance.tracker(owner)
      const contractInitialBalance = await contractBalanceTracker.get()
      const ownerInitialBalance = await ownerBalanceTracker.get()

      // Report data request result from Witnet to WitnetRequestBoard
      const reportResultTx = await this.WitnetRequestBoard.reportResult(
        queryId, drTxHash, resultHex,
        { from: owner, gasPrice: 1 }
      )

      // Check `PostedRequest` event
      expectEvent(
        reportResultTx,
        "PostedResult",
        {
          queryId: queryId,
        },
      )
      expect(reportResultTx.logs[0].args.queryId, "match data request id").to.be.bignumber.equal(queryId)

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
    it("fails if reporter is not a committee member", async () => {
      await expectRevert(
        this.WitnetRequestBoard.reportResult(queryId, drTxHash, resultHex, {
          from: other,
          gasPrice: 1,
        }),
        "unauthorized reporter"
      )
    })
    it("fails if trying to report with zero as Witnet drTxHash", async () => {
      await expectRevert(
        this.WitnetRequestBoard.reportResult(
          queryId, "0x0", resultHex,
          { from: owner, gasPrice: 1 }
        ),
        "drTxHash cannot be zero"
      )
    })
    it("fails if result was already reported", async () => {
      // Report data request result from Witnet to WitnetRequestBoard
      await this.WitnetRequestBoard.reportResult(
        queryId, drTxHash, resultHex,
        { from: owner, gasPrice: 1 }
      )

      // Try to report the result of the previous data request
      await expectRevert(
        this.WitnetRequestBoard.reportResult(queryId, drTxHash, resultHex, {
          from: committeeMember,
          gasPrice: 1,
        }),
        "not in Posted status"
      )
    })
    it("fails if data request has not been posted", async () => {
      await expectRevert(
        this.WitnetRequestBoard.reportResult(
          queryId.add(new BN(1)), drTxHash, resultHex,
          { from: owner, gasPrice: 1 }
        ),
        "not in Posted status"
      )
    })
    it("fails if trying to read bytecode from solved data request", async () => {
      await this.WitnetRequestBoard.reportResult(
        queryId, drTxHash, resultHex,
        { from: owner, gasPrice: 1 }
      )
      await expectRevert(
        this.WitnetRequestBoard.readRequestBytecode(queryId),
        "not in Posted status"
      )
    })
  })

  describe("read data request result", async () => {
    let requestTestHelper
    beforeEach(async () => {
      requestTestHelper = await WitnetRequestTestHelper.new(requestHex, { from: requester })
      // Post data request
      await this.WitnetRequestBoard.postRequest(requestTestHelper.address, {
        from: requester,
        value: ether("1"),
      })
      // Report data request result from Witnet to WitnetRequestBoard
      await this.WitnetRequestBoard.reportResult(queryId, drTxHash, resultHex, {
        from: committeeMember,
        gasPrice: 1,
      })
    })
    it("anyone can read the data request result", async () => {
      // Read data request result from WitnetRequestBoard by `queryId`
      const result = await this.WitnetRequestBoard.readResponseResult(queryId, { from: requester })
      expect(result.value.buffer.data).to.be.equal(resultHex)
    })
    it("should revert reading data for non-existent Ids", async () => {
      await expectRevert(this.WitnetRequestBoard.readRequestBytecode.call(200), "not in Posted status")
      await expectRevert(this.WitnetRequestBoard.readResponseDrTxHash.call(200), "not in Reported status")
      await expectRevert(this.WitnetRequestBoard.readResponseResult.call(200), "not in Reported status")
    })
  })

  describe("read data request gas price", async () => {
    beforeEach(async () => {
      await this.WitnetRequestBoard.postRequest(
        this.WitnetRequest.address,
        {
          from: requester,
          value: ether("1"),
          gasPrice: 1,
        }
      )
    })
    it("anyone can read data request gas price", async () => {
      // Read data request gas price from WitnetRequestBoard by `queryId`
      const gasPrice = await this.WitnetRequestBoard.readRequestGasPrice.call(queryId, { from: other })
      expect(
        gasPrice.eq(new BN("1")),
        "data request gas price should have been set to 1 wei",
      ).to.equal(true)
    })
  })

  describe("estimate gas cost", async () => {
    it("anyone can estime a data request gas cost", async () => {
      // Gas price = 1
      const maxResRe = new BN(135000)
      const reward = await this.WitnetRequestBoard.estimateReward.call(1)
      expect(
        reward.lte(maxResRe),
        `The estimated maximum gas cost for result reward should be less than ${maxResRe.toString()}`
      ).to.equal(true)
    }
    )
  })

  describe("delete data request", async () => {
    let drId
    beforeEach(async () => {
      const tx = await this.WitnetRequestBoard.postRequest(
        this.WitnetRequest.address,
        {
          from: requester,
          value: ether("0.1"),
          gasPrice: 1,
        }
      )
      drId = tx.logs[0].args[0]
    })
    it("fails if trying to delete data request from non requester address", async () => {
      await this.WitnetRequestBoard.reportResult(
        drId, drTxHash, resultHex,
        { from: owner, gasPrice: 1 }
      )
      await expectRevert(
        this.WitnetRequestBoard.deleteQuery(drId, { from: other }),
        "only requester"
      )
    })
    it("unsolved data request cannot be deleted", async () => {
      await expectRevert(
        this.WitnetRequestBoard.deleteQuery(drId, { from: requester }),
        "not in Reported status"
      )
    })
    it("requester can delete solved data request", async () => {
      await this.WitnetRequestBoard.reportResult(
        drId, drTxHash, resultHex,
        { from: owner, gasPrice: 1 }
      )
      await this.WitnetRequestBoard.deleteQuery(drId, { from: requester })
    })
    it("fails if reporting result on deleted data request", async () => {
      await this.WitnetRequestBoard.reportResult(
        drId, drTxHash, resultHex,
        { from: owner, gasPrice: 1 }
      )
      await this.WitnetRequestBoard.deleteQuery(drId, { from: requester })
      await expectRevert(
        this.WitnetRequestBoard.reportResult(
          drId, drTxHash, resultHex,
          { from: owner, gasPrice: 1 }
        ),
        "not in Posted status"
      )
    })
    it("fails if trying to read bytecode from deleted data request", async () => {
      await this.WitnetRequestBoard.reportResult(
        drId, drTxHash, resultHex,
        { from: owner, gasPrice: 1 }
      )
      await this.WitnetRequestBoard.deleteQuery(drId, { from: requester })
      await expectRevert(
        this.WitnetRequestBoard.readRequestBytecode(drId),
        "not in Posted status"
      )
    })
  })

  describe("interfaces", async () => {
    describe("Upgradable:", async () => {
      it("initialization fails if called from non owner address", async () => {
        await expectRevert(
          this.WitnetRequestBoard.initialize(
            web3.eth.abi.encodeParameter("address[]", [other]),
            { from: other }
          ),
          "only owner"
        )
      })
      it("cannot initialize same instance more than once", async () => {
        await expectRevert(
          this.WitnetRequestBoard.initialize(
            web3.eth.abi.encodeParameter("address[]", [other]),
            { from: owner }
          ),
          "already initialized"
        )
      })
    })

    describe("Destructible:", async () => {
      it("fails if trying to destruct from non owner address", async () => {
        await expectRevert(
          this.WitnetRequestBoard.destruct({ from: other }),
          "only owner"
        )
      })
      it("instance gets actually destructed", async () => {
        await this.WitnetRequestBoard.destruct({ from: owner })
        await expectRevert(
          this.WitnetRequestBoard.getNextQueryId(),
          "Out of Gas?"
        )
      })
      it("fails if trying to delete unposted DR", async () => {
        await expectRevert(
          this.WitnetRequestBoard.deleteQuery(200, { from: owner }),
          "not in Reported status"
        )
      })
    })
  })
})
