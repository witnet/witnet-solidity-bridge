const settings = require("../migrations/witnet.settings")

const {
  BN,
  expectEvent,
  expectRevert,
  balance,
  ether,
} = require("@openzeppelin/test-helpers")
const { expect, assert } = require("chai")

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
          queryId,
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
          queryId,
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
          gasPrice: 1e9,
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
        gasPrice: 2e9,
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
        gasPrice: 3e9,
      })

      // Read data request gas price from WitnetRequestBoard by `queryId`
      const gasPrice = await this.WitnetRequestBoard.readRequestGasPrice.call(queryId, { from: other })

      // Check that gas price has been updated to 3 wei
      expect(
        gasPrice.eq(new BN(3e9)),
        "data request gas price should have been set to 3 gwei",
      ).to.equal(true)
    })
    it("creator cannot decrease existing data request gas price", async () => {
      // Update data request (increased reward)
      await this.WitnetRequestBoard.upgradeReward(queryId, {
        from: requester,
        value: ether("1"),
        gasPrice: 3e9,
      })
      // Read data request gas price from WitnetRequestBoard by `queryId`
      const gasPrice = await this.WitnetRequestBoard.readRequestGasPrice.call(queryId, { from: other })
      // Check that gas price has not been updated to 1 wei
      expect(
        gasPrice.eq(new BN(3e9)),
        "data request gas price should not have been set to 1 gwei",
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
        { from: owner, gasPrice: 1e9 }
      )
      // Update data request (increased reward)
      await expectRevert(
        this.WitnetRequestBoard.upgradeReward(queryId, {
          from: requester,
          value: ether("1"),
          gasPrice: 3e9,
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
        gasPrice: 1e9,
      })
    })
    it("committee members can report a request result from Witnet and it should receive the reward", async () => {
      // Initial balances
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
      const ownerBalanceTracker = await balance.tracker(owner)
      const contractInitialBalance = await contractBalanceTracker.get()
      const ownerInitialBalance = await ownerBalanceTracker.get()

      // Report data request result from Witnet to WitnetRequestBoard
      const reportResultTx = await this.WitnetRequestBoard.reportResult(
        queryId, drTxHash, resultHex,
        { from: owner, gasPrice: 1e9 }
      )

      // Check `PostedRequest` event
      expectEvent(
        reportResultTx,
        "PostedResult",
        {
          queryId,
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
        ownerFinalBalance.gt(ownerInitialBalance),
        "Owner balance should have increased after reporting result",
      ).to.equal(true)
    })
    it("fails if reporter is not a committee member", async () => {
      await expectRevert(
        this.WitnetRequestBoard.reportResult(queryId, drTxHash, resultHex, {
          from: other,
          gasPrice: 1e9,
        }),
        "unauthorized reporter"
      )
    })
    it("fails if trying to report with zero as Witnet drTxHash", async () => {
      await expectRevert(
        this.WitnetRequestBoard.reportResult(
          queryId, "0x0", resultHex,
          { from: owner, gasPrice: 1e9 }
        ),
        "drTxHash cannot be zero"
      )
    })
    it("fails if result was already reported", async () => {
      // Report data request result from Witnet to WitnetRequestBoard
      await this.WitnetRequestBoard.reportResult(
        queryId, drTxHash, resultHex,
        { from: owner, gasPrice: 1e9 }
      )

      // Try to report the result of the previous data request
      await expectRevert(
        this.WitnetRequestBoard.reportResult(queryId, drTxHash, resultHex, {
          from: committeeMember,
          gasPrice: 1e9,
        }),
        "not in Posted status"
      )
    })
    it("fails if data request has not been posted", async () => {
      await expectRevert(
        this.WitnetRequestBoard.reportResult(
          queryId.add(new BN(1)), drTxHash, resultHex,
          { from: owner, gasPrice: 1e9 }
        ),
        "not in Posted status"
      )
    })
    it("retrieves null array if trying to read bytecode from solved data request", async () => {
      await this.WitnetRequestBoard.reportResult(
        queryId, drTxHash, resultHex,
        { from: owner, gasPrice: 1e9 }
      )
      const bytecode = await this.WitnetRequestBoard.readRequestBytecode.call(queryId)
      assert(bytecode == null)
    })
  })

  describe("batch report multiple results", async () => {
    beforeEach(async () => {
      for (let j = 0; j < 3; j++) {
        await this.WitnetRequestBoard.postRequest(
          this.WitnetRequest.address, {
            from: requester,
            value: ether("1"),
            gasPrice: 1e9,
          }
        )
      }
    })
    it("fails if trying to batch report valid results from unauthorized address", async () => {
      await expectRevert(
        this.WitnetRequestBoard.reportResultBatch(
          [
            [1, 0, drTxHash, resultHex],
            [2, 0, drTxHash, resultHex],
            [3, 0, drTxHash, resultHex],
          ],
          true,
          { from: other, gasPrice: 1e9 }
        ),
        "unauthorized reporter"
      )
    })
    it("committee member can batch report multiple results, and receive the sum of all rewards", async () => {
      // Initial balances
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
      const ownerBalanceTracker = await balance.tracker(owner)
      const contractInitialBalance = await contractBalanceTracker.get()
      const ownerInitialBalance = await ownerBalanceTracker.get()

      // Report data request result from Witnet to WitnetRequestBoard
      const tx = await this.WitnetRequestBoard.reportResultBatch(
        [
          [1, 0, drTxHash, resultHex],
          [2, 0, drTxHash, resultHex],
          [3, 0, drTxHash, resultHex],
        ],
        false,
        { from: owner, gasPrice: 1e9 }
      )

      // Check balances (contract decreased and claimer increased)
      const contractFinalBalance = await contractBalanceTracker.get()
      const ownerFinalBalance = await ownerBalanceTracker.get()
      expect(
        contractFinalBalance.eq(contractInitialBalance
          .sub(ether("3"))
        ),
        "contract balance should have decreased after reporting dr request result by 3 eth",
      ).to.equal(true)
      expect(
        ownerFinalBalance.gt(ownerInitialBalance),
        "Owner balance should have increased after reporting result",
      ).to.equal(true)

      // Check number of PostedResult events
      expect(
        tx.logs.filter(log => log.event === "PostedResult").length,
        "PostedResult event should have been emitted three times"
      ).to.equal(3)
    })
    it(
      "trying to verbose batch report same query twice, should pay reward once and emit error event once",
      async () => {
      // Initial balances
        const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
        const ownerBalanceTracker = await balance.tracker(owner)
        const contractInitialBalance = await contractBalanceTracker.get()
        const ownerInitialBalance = await ownerBalanceTracker.get()

        // Report data request result from Witnet to WitnetRequestBoard
        const tx = await this.WitnetRequestBoard.reportResultBatch(
          [
            [3, 0, drTxHash, resultHex],
            [3, 0, drTxHash, resultHex],
          ],
          true,
          { from: owner, gasPrice: 1e9 }
        )

        // Check balances (contract decreased and claimer increased)
        const contractFinalBalance = await contractBalanceTracker.get()
        const ownerFinalBalance = await ownerBalanceTracker.get()
        expect(
          contractFinalBalance.eq(contractInitialBalance
            .sub(ether("1"))
          ),
          "contract balance should have decreased after reporting dr request result by 3 eth",
        ).to.equal(true)
        expect(
          ownerFinalBalance.gt(ownerInitialBalance),
          "Owner balance should have increased after reporting result",
        ).to.equal(true)

        // Check number of emitted PostedResult events:
        expect(
          tx.logs.filter(log => log.event === "PostedResult").length,
          "PostedResult event should have been emitted once"
        ).to.equal(1)

        // Check number and quality of BatchReportError events:
        const errors = tx.logs.filter(log => log.event === "BatchReportError")
        expect(
          errors.length,
          "BatchReportResult event should have been emitted just once"
        ).to.equal(1)
        expect(
          errors[0].args.queryId.toString(),
          "BatchReportResult event refers unexpected query id"
        ).to.equal("3")
        expect(
          errors[0].args.reason,
          "BatchReportResult manifest wrong reason"
        ).to.contain("bad queryId")
      })
    it(
      "reporting bad drTxHash within non-verbose batch, should pay rewards for valid results and emit no error event",
      async () => {
      // Initial balances
        const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
        const ownerBalanceTracker = await balance.tracker(owner)
        const contractInitialBalance = await contractBalanceTracker.get()
        const ownerInitialBalance = await ownerBalanceTracker.get()

        // Report data request result from Witnet to WitnetRequestBoard
        const tx = await this.WitnetRequestBoard.reportResultBatch(
          [
            [1, 0, drTxHash, resultHex],
            [2, 0, "0x0000000000000000000000000000000000000000000000000000000000000000", resultHex],
            [3, 0, drTxHash, resultHex],
          ],
          false,
          { from: owner, gasPrice: 1e9 }
        )

        // Check balances (contract decreased and claimer increased)
        const contractFinalBalance = await contractBalanceTracker.get()
        const ownerFinalBalance = await ownerBalanceTracker.get()
        expect(
          contractFinalBalance.eq(contractInitialBalance
            .sub(ether("2"))
          ),
          "contract balance should have decreased after reporting dr request result by 2 eth",
        ).to.equal(true)
        expect(
          ownerFinalBalance.gt(ownerInitialBalance),
          "Owner balance should have increased after reporting result",
        ).to.equal(true)

        // Check number of emitted PostedResult events:
        expect(
          tx.logs.filter(log => log.event === "PostedResult").length,
          "PostedResult event should have been emitted three times"
        ).to.equal(2)

        // Check number of BatchReportError events:
        const errors = tx.logs.filter(log => log.event === "BatchReportError")
        expect(
          errors.length,
          "No BatchReportResult events should have been emitted"
        ).to.equal(0)
      })
    it(
      "reporting bad results within verbose batch, should pay no reward and emit no PostedResult events", async () => {
      // Initial balances
        const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
        const contractInitialBalance = await contractBalanceTracker.get()

        // Report data request result from Witnet to WitnetRequestBoard
        const tx = await this.WitnetRequestBoard.reportResultBatch(
          [
            [1, 0, drTxHash, "0x"],
            [3, 0, "0x0000000000000000000000000000000000000000000000000000000000000000", resultHex],
            [2, 4070905200 /* 2099-01-01 00:00:00 UTC */, drTxHash, resultHex],
          ],
          true,
          { from: owner, gasPrice: 1e9 }
        )

        // Check balances (contract decreased and claimer increased)
        const contractFinalBalance = await contractBalanceTracker.get()
        expect(
          contractFinalBalance.eq(
            contractInitialBalance
          ),
          "contract balance should have not changed",
        ).to.equal(true)

        // Check number of emitted PostedResult events:
        expect(
          tx.logs.filter(log => log.event === "PostedResult").length,
          "Should have not emitted any PostedResult event"
        ).to.equal(0)

        // Check number and quality of BatchReportError events:
        const errors = tx.logs.filter(log => log.event === "BatchReportError")
        expect(
          errors.length,
          "Three BatchReportResult events should have been emitted"
        ).to.equal(3)
        expect(
          errors[0].args.queryId.toString(),
          "First BatchReportResult event refers to unexpected query id"
        ).to.equal("1")
        expect(
          errors[0].args.reason,
          "First BatchReportResult manifests wrong reason"
        ).to.contain("bad cborBytes")
        expect(
          errors[1].args.queryId.toString(),
          "Second BatchReportResult event refers to unexpected query id"
        ).to.equal("3")
        expect(
          errors[1].args.reason,
          "Second BatchReportResult manifests wrong reason"
        ).to.contain("bad drTxHash")
        expect(
          errors[2].args.queryId.toString(),
          "Third BatchReportResult event refers to unexpected query id"
        ).to.equal("2")
        expect(
          errors[2].args.reason,
          "Third BatchReportResult manifests wrong reason"
        ).to.contain("bad timestamp")
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
        gasPrice: 1e9,
      })
    })
    it("anyone can read the data request result", async () => {
      // Read data request result from WitnetRequestBoard by `queryId`
      const result = await this.WitnetRequestBoard.readResponseResult(queryId, { from: requester })
      expect(result.value.buffer.data).to.be.equal(resultHex)
    })
    it("should revert reading data for non-existent Ids", async () => {
      await expectRevert(this.WitnetRequestBoard.readRequestBytecode.call(200), "not yet posted")
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
          gasPrice: 1e9,
        }
      )
    })
    it("anyone can read data request gas price", async () => {
      // Read data request gas price from WitnetRequestBoard by `queryId`
      const gasPrice = await this.WitnetRequestBoard.readRequestGasPrice.call(queryId, { from: other })
      expect(
        gasPrice.eq(new BN(1e9)),
        "data request gas price should have been set to 1 gwei",
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
          gasPrice: 1e9,
        }
      )
      drId = tx.logs[0].args[0]
    })
    it("fails if trying to delete data request from non requester address", async () => {
      await this.WitnetRequestBoard.reportResult(
        drId, drTxHash, resultHex,
        { from: owner, gasPrice: 1e9 }
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
        { from: owner, gasPrice: 1e9 }
      )
      await this.WitnetRequestBoard.deleteQuery(drId, { from: requester })
    })
    it("fails if reporting result on deleted data request", async () => {
      await this.WitnetRequestBoard.reportResult(
        drId, drTxHash, resultHex,
        { from: owner, gasPrice: 1e9 }
      )
      await this.WitnetRequestBoard.deleteQuery(drId, { from: requester })
      await expectRevert(
        this.WitnetRequestBoard.reportResult(
          drId, drTxHash, resultHex,
          { from: owner, gasPrice: 1e9 }
        ),
        "not in Posted status"
      )
    })
    it("retrieves null array if trying to read bytecode from deleted data request", async () => {
      await this.WitnetRequestBoard.reportResult(
        drId, drTxHash, resultHex,
        { from: owner, gasPrice: 1e9 }
      )
      await this.WitnetRequestBoard.deleteQuery(drId, { from: requester })
      const bytecode = await this.WitnetRequestBoard.readRequestBytecode.call(drId)
      assert(bytecode == null)
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
