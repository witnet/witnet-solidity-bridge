const {
  BN,
  expectEvent,
  expectRevert,
  balance,
  ether,
} = require("@openzeppelin/test-helpers")
const { web3 } = require("@openzeppelin/test-helpers/src/setup")
const { expect } = require("chai")
const sha256 = require("js-sha256").sha256

// Contracts
const MockBlockRelay = artifacts.require("MockBlockRelay")
const BlockRelayProxy = artifacts.require("BlockRelayProxy")
const WRB = artifacts.require("WitnetRequestsBoard")
const WRBHelper = artifacts.require("WitnetRequestsBoardTestHelper")

const Request = artifacts.require("Request")

/*
 * Test Fixtures
 */
const data = require("./data.json")

// Request definition
const requestId = new BN(1)
// eslint-disable-next-line no-multi-str
const requestHex = "0x0abb0108bd8cb8fa05123b122468747470733a2f2f7777772e6269747374616d702e6e65742f6170692f7469636b65722\
f1a13841877821864646c6173748218571903e8185b125c123168747470733a2f2f6170692e636f696e6465736b2e636f6d2f76312f6270692f6375\
7272656e7470726963652e6a736f6e1a2786187782186663627069821866635553448218646a726174655f666c6f61748218571903e8185b1a0d0a0\
908051205fa3fc00000100322090a0508051201011003100a1804200128\
46308094ebdc03"
const resultHex = "0x1a000702c8"
const drOutputHash = "0x" + sha256(web3.utils.hexToBytes(requestHex))

// Request inclusion definition (Proof-of-Inclusion)
const epoch = 2
const blockHeader = "0x" + sha256("block header")
const roots = calculateRoots(0, requestHex, resultHex)

// Function to calculate merkle roots for Proof-of-Inclusions (PoI)
function calculateRoots (levels, drBytes, resBytes) {
  let hash = sha256.create()
  hash.update(web3.utils.hexToBytes(drBytes))
  const drHash = "0x" + hash.hex()
  hash = sha256.create()
  hash.update(web3.utils.hexToBytes(drHash))
  hash.update(web3.utils.hexToBytes(drHash))
  const drTxHash = "0x" + hash.hex()
  let temp = drTxHash
  for (let i = 0; i < levels; i++) {
    hash = sha256.create()
    hash.update(web3.utils.hexToBytes(temp))
    hash.update(web3.utils.hexToBytes(drHash))
    temp = "0x" + hash.hex()
  }
  const expectedDrHash = temp
  hash = sha256.create()
  hash.update(web3.utils.hexToBytes(drTxHash))
  hash.update(web3.utils.hexToBytes(resBytes))
  temp = "0x" + hash.hex()
  for (let i = 0; i < levels; i++) {
    hash = sha256.create()
    hash.update(web3.utils.hexToBytes(temp))
    hash.update(web3.utils.hexToBytes(drHash))
    temp = "0x" + hash.hex()
  }
  const expectedResHash = temp
  return [expectedDrHash, expectedResHash]
}

contract("WitnetRequestBoard", ([
  requestor,
  claimer,
  owner,
  other,
]) => {
  beforeEach(async () => {
    this.BlockRelay = await MockBlockRelay.new({ from: owner })
    this.BlockRelayProxy = await BlockRelayProxy.new(this.BlockRelay.address, { from: owner })
    this.WitnetRequestBoard = await WRB.new(this.BlockRelayProxy.address, 2, { from: owner })
    this.WitnetRequestBoardTestHelper = await WRBHelper.new(this.BlockRelayProxy.address, 2, { from: owner })
    this.Request = await Request.new(requestHex, { from: requestor })
  })

  describe("deployments", async () => {
    it("deploys BlockRelay successfully", async () => {
      expect(this.BlockRelay.address != null)
    })
    it("deploys BlockRelayProxy successfully", async () => {
      expect(this.BlockRelayProxy.address != null)
    })
    it("deploys WitnetRequestBoard successfully", async () => {
      expect(this.WitnetRequestBoard.address != null)
    })
    it("deploys WitnetRequestBoard successfully", async () => {
      expect(this.WitnetRequestBoardTestHelper.address != null)
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
        ether("0.25"),
        ether("0.5"), {
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
          ether("0.5"),
          ether("0.5"), {
            from: requestor,
            value: ether("0"),
            gasPrice: 1,
          }
        ),
        "Transaction value needs to be equal or greater than tally plus inclusion reward"
      )
    })
    it("fails if creator is not covering DR inclusion gas cost", async () => {
      // Inclusion reward < MAX_CLAIM_DR_GAS + MAX_DR_INCLUSION_GAS
      await expectRevert(
        this.WitnetRequestBoard.postDataRequest(
          this.Request.address,
          new BN("1"),
          ether("0.5"), {
            from: requestor,
            value: ether("0.5").add(new BN("1")),
            gasPrice: 1,
          }
        ),
        "Inclusion reward should cover gas expenses"
      )
    })
    it("fails if creator is not covering DR result report gas cost", async () => {
      // Tally reward < MAX_REPORT_RESULT_GAS
      await expectRevert(
        this.WitnetRequestBoard.postDataRequest(
          this.Request.address,
          ether("0.5"),
          new BN("1"), {
            from: requestor,
            value: ether("0.5").add(new BN("1")),
            gasPrice: 1,
          }
        ),
        "Report result reward should cover gas expenses"
      )
    })
    it("fails if creator is not covering block report gas cost", async () => {
      // Tally reward < MAX_REPORT_BLOCK_GAS
      await expectRevert(
        this.WitnetRequestBoard.postDataRequest(
          this.Request.address,
          ether("0.5"),
          ether("0.5"), {
            from: requestor,
            value: ether("1"),
            gasPrice: 1,
          }
        ),
        "Block reward should cover gas expenses"
      )
    })
  })

  describe("read data request gas price", async () => {
    beforeEach(async () => {
      await this.WitnetRequestBoard.postDataRequest(
        this.Request.address,
        ether("0.25"),
        ether("0.5"), {
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
        ether("0.25"),
        ether("0.5"), {
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
      await this.WitnetRequestBoard.upgradeDataRequest(requestId, ether("0.5"), ether("0.25"), {
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
      await this.WitnetRequestBoard.upgradeDataRequest(requestId, ether("0.5"), ether("0.25"), {
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
      await this.WitnetRequestBoard.upgradeDataRequest(requestId, ether("0.5"), ether("0.25"), {
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
    it("fails if creator is not covering DR inclusion gas cost", async () => {
      const gasPrice = ether("0.000001")
      const claimDrGas = await this.WitnetRequestBoard.MAX_CLAIM_DR_GAS.call()
      const includeDrGas = await this.WitnetRequestBoard.MAX_DR_INCLUSION_GAS.call()
      const inclusionGas = claimDrGas.add(includeDrGas)

      // Multiply by gas price and substract the already existing value to the limit
      const maxInclusionInvalidReward = (inclusionGas.mul(gasPrice)).sub(ether("0.25")).sub(new BN("1"))

      // Transaction value < rewards
      await expectRevert(
        this.WitnetRequestBoard.upgradeDataRequest(requestId, maxInclusionInvalidReward, ether("0"), {
          from: requestor,
          value: ether("10"),
          gasPrice: gasPrice,
        }),
        "Inclusion reward should cover gas expenses"
      )
    })
    it("fails if creator is not covering DR result report gas cost", async () => {
      const gasPrice = ether("0.000005")
      const claimDrGas = await this.WitnetRequestBoard.MAX_CLAIM_DR_GAS.call()
      const includeDrGas = await this.WitnetRequestBoard.MAX_DR_INCLUSION_GAS.call()
      const inclusionGas = claimDrGas.add(includeDrGas)
      const postResultGas = await this.WitnetRequestBoard.MAX_REPORT_RESULT_GAS.call()

      // Multiply by gas price and substract the already existing value to the limit
      const minInclusionValidReward = (inclusionGas.mul(gasPrice)).sub(ether("0.25"))
      const maxResultInvalidReward = (postResultGas.mul(gasPrice)).sub(ether("0.5")).sub(new BN("1"))

      // Transaction value < rewards
      await expectRevert(
        this.WitnetRequestBoard.upgradeDataRequest(requestId, minInclusionValidReward, maxResultInvalidReward, {
          from: requestor,
          value: ether("10"),
          gasPrice: gasPrice,
        }),
        "Report result reward should cover gas expenses"
      )
    })
    it("fails if creator is not covering block report gas cost", async () => {
      const gasPrice = ether("0.000005")
      const claimDrGas = await this.WitnetRequestBoard.MAX_CLAIM_DR_GAS.call()
      const includeDrGas = await this.WitnetRequestBoard.MAX_DR_INCLUSION_GAS.call()
      const inclusionGas = claimDrGas.add(includeDrGas)
      const postResultGas = await this.WitnetRequestBoard.MAX_REPORT_RESULT_GAS.call()
      const postBlockGas = await this.WitnetRequestBoard.MAX_REPORT_BLOCK_GAS.call()

      // Multiply by gas price and substract the already existing value to the limit
      const minInclusionValidReward = (inclusionGas.mul(gasPrice)).sub(ether("0.25"))
      const minResultValidReward = (postResultGas.mul(gasPrice)).sub(ether("0.5"))
      const maxBlockInvalidReward = (postBlockGas.mul(gasPrice)).sub(ether("0.25")).sub(new BN("1"))

      // Transaction value < rewards
      await expectRevert(
        this.WitnetRequestBoard.upgradeDataRequest(requestId, minInclusionValidReward, minResultValidReward, {
          from: requestor,
          value: minResultValidReward.add(minInclusionValidReward).add(maxBlockInvalidReward),
          gasPrice: gasPrice,
        }),
        "Block reward should cover gas expenses"
      )
    })
  })

  describe("claim data request", async () => {
    beforeEach(async () => {
      await this.WitnetRequestBoard.postDataRequest(this.Request.address, ether("0.25"), ether("0.5"), {
        from: requestor,
        value: ether("1"),
      })
    })
    it("claimer can claim a data request", async () => {
      /*
       * Claim parameters for a Witnet node trying to claim a data request
       */

      // Claimer's Witnet public Key (not Ethereum public key)
      const publicKey = [data.publicKey.x, data.publicKey.y]

      // VRF proof using node's identity and using as param `[blockHash | epoch]`
      //
      // Node JSON-RPC command to generate a VRF using as parameter the concatenated bytes of `[blockHash | epoch]`:
      //
      // ```bash
      //  echo '{ \
      //    "jsonrpc":"2.0", \
      //    "id":"1", \
      //    "method":"createVRF", \
      //    "params": [ \
      //      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, \
      //      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 \
      //    ] \
      //  }' | cargo run -- -c witnet_1.toml node raw
      /// ```
      const proofMessage = data.poe[0].lastBeacon
      const proofBytes = data.poe[0].proof

      // Signature of the claimer Ethereum address (`msg.sender`) by using the Witnet's identity (not Ethereum address)
      // The Witnet node has to sign the output of the digest (SHA256) of the Ethereum address
      //
      // Node JSON-RPC command to sign the bytes of the output of `sha256(msg.sender)`:
      //
      // ```bash
      //  echo '{ \
      //    "jsonrpc":"2.0", \
      //    "id":"1", \
      //    "method":"sign", \
      //    "params": [ \
      //      178, 247, 241,  42, 234, 190, 248, 252,  88, 175, 96, 221, 85, 162, 133, 25, \
      //      217, 191, 159, 250, 143, 175, 131,  25, 187, 251, 42, 171, 15, 180, 122, 86 \
      //    ] \
      //  }' | cargo run -- -c witnet_1.toml node raw
      // ```
      //
      // The signature output is in DER format, and should be converted to r,s,v format.
      // A correct DER-encoded signature has the following form:
      //  - 0x30: a header byte indicating a compound structure.
      //  - A 1-byte length descriptor for all what follows.
      //  - 0x02: a header byte indicating an integer.
      //  - A 1-byte length descriptor for the R value
      //  - The R coordinate, as a big-endian integer.
      //  - 0x02: a header byte indicating an integer.
      //  - A 1-byte length descriptor for the S value.
      //  - The S coordinate, as a big-endian integer.
      //
      // Additionally, V parity bit should be provided, which is  either 0x00 or 0x01.
      const signature = data.signature

      // Use auxiliary functions to decode proof and compute the VRF fast verification inputs
      const proof = await this.WitnetRequestBoard.decodeProof(proofBytes)
      const fastVerifyParams = await this.WitnetRequestBoard.computeFastVerifyParams(publicKey, proof, proofMessage)

      // Claim data request (should not revert)
      await this.WitnetRequestBoard.claimDataRequests(
        [requestId],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: claimer,
        })
    })
  })

  describe("report data request inclusion", async () => {
    beforeEach(async () => {
      // Post data request
      await this.WitnetRequestBoard.postDataRequest(this.Request.address, ether("0.25"), ether("0.5"), {
        from: requestor,
        value: ether("1"),
      })
      // Claim data request
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const message = data.poe[0].lastBeacon
      const signature = data.signature
      const proof = await this.WitnetRequestBoard.decodeProof(proofBytes)
      const fastVerifyParams = await this.WitnetRequestBoard.computeFastVerifyParams(publicKey, proof, message)
      await this.WitnetRequestBoard.claimDataRequests(
        [requestId],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: claimer,
        })
    })
    it("fails if block is not posted", async () => {
      await expectRevert(
        this.WitnetRequestBoard.reportDataRequestInclusion(
          requestId,
          [drOutputHash],
          0,
          blockHeader,
          epoch,
          { from: claimer },
        ),
        "Non-existing block"
      )
    })
    it("anyone can report data request inclusion from Witnet (0.5 eth to claimer)", async () => {
      // Initial balances
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
      const claimerBalanceTracker = await balance.tracker(claimer)
      const ownerBalanceTracker = await balance.tracker(owner)
      const contractInitialBalance = await contractBalanceTracker.get()
      const claimerInitialBalance = await claimerBalanceTracker.get()

      // Post new block and report data request inclusion
      await this.BlockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: owner,
      })

      // Get the owner balance after posting block
      const ownerInitialBalance = await ownerBalanceTracker.get()
      await this.WitnetRequestBoard.reportDataRequestInclusion(requestId, [drOutputHash], 0, blockHeader, epoch, {
        from: other,
      })

      // Check balances (contract decreased and claimer and owner increased)
      const contractFinalBalance = await contractBalanceTracker.get()
      const claimerFinalBalance = await claimerBalanceTracker.get()
      const ownerFinalBalance = await ownerBalanceTracker.get()

      expect(
        contractFinalBalance.eq(contractInitialBalance
          .sub(ether("0.375"))
        ),
        "contract balance should have decreased after reporting dr request inclusion by 0.375 eth",
      ).to.equal(true)
      expect(
        claimerFinalBalance.eq(claimerInitialBalance
          .add(ether("0.25"))
        ),
        "claimer balance should have increased after reporting dr request inclusion by 0.25 eth",
      ).to.equal(true)
      expect(
        ownerFinalBalance.eq(ownerInitialBalance
          .add(ether("0.125"))
        ),
        "Owner balance should have increased after reporting b lock by 0.125 eth",
      ).to.equal(true)
    })
  })

  describe("report data request inclusion pushing the limtis (9 PoI levels and activity to be removed)", async () => {
    beforeEach(async () => {
      await this.WitnetRequestBoardTestHelper.setBlockNumber(0)
      // Post data request
      await this.WitnetRequestBoardTestHelper.postDataRequest(this.Request.address, ether("0.5"), ether("0.25"), {
        from: requestor,
        value: ether("1"),
      })
      // Claim data request
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const message = data.poe[0].lastBeacon
      const signature = data.signature
      const proof = await this.WitnetRequestBoardTestHelper.decodeProof(proofBytes)
      const fastVerParams = await this.WitnetRequestBoardTestHelper.computeFastVerifyParams(publicKey, proof, message)

      // We push activity for the 50 slots
      for (let i = 0; i < (8 * 50) - 1; i += 8) {
        await this.WitnetRequestBoardTestHelper.pushActivity(claimer, i)
      }

      // We set the block number so that a full acitivity removal needs to be performed
      await this.WitnetRequestBoardTestHelper.setBlockNumber((8 * 50 * 2) - 1)

      await this.WitnetRequestBoardTestHelper.claimDataRequests(
        [requestId],
        proof,
        publicKey,
        fastVerParams[0],
        fastVerParams[1],
        signature, {
          from: claimer,
        })
    })
    it("Pushing the limits to 9 additional PoI levels (0.5 eth to claimer) plus activity to be removed", async () => {
      // Initial balances
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoardTestHelper.address)
      const claimerBalanceTracker = await balance.tracker(claimer)
      const contractInitialBalance = await contractBalanceTracker.get()
      const claimerInitialBalance = await claimerBalanceTracker.get()
      const roots = calculateRoots(9, requestHex, resultHex)
      const proof = Array(10).fill(drOutputHash)
      // Post new block and report data request inclusion
      await this.BlockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: owner,
      })
      await this.WitnetRequestBoardTestHelper.reportDataRequestInclusion(requestId, proof, 0, blockHeader, epoch, {
        from: other,
      })

      // Check balances (contract decreased and claimer increased)
      const contractFinalBalance = await contractBalanceTracker.get()
      const claimerFinalBalance = await claimerBalanceTracker.get()
      expect(
        contractFinalBalance.eq(contractInitialBalance
          .sub(ether("0.625"))
        ),
        "contract balance should have decreased after reporting dr request inclusion by 0.5 eth",
      ).to.equal(true)
      expect(
        claimerFinalBalance.eq(claimerInitialBalance
          .add(ether("0.5"))
        ),
        "claimer balance should have increased after reporting dr request inclusion by 0.5 eth",
      ).to.equal(true)
    })
  })

  describe("report data request result", async () => {
    beforeEach(async () => {
      // Post data request
      await this.WitnetRequestBoard.postDataRequest(this.Request.address, ether("0.25"), ether("0.5"), {
        from: requestor,
        value: ether("1"),
      })
      // Claim data request
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const message = data.poe[0].lastBeacon
      const signature = data.signature
      const proof = await this.WitnetRequestBoard.decodeProof(proofBytes)
      const fastVerifyParams = await this.WitnetRequestBoard.computeFastVerifyParams(publicKey, proof, message)
      await this.WitnetRequestBoard.claimDataRequests(
        [requestId],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: claimer,
        })
      // Post new block
      await this.BlockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: owner,
      })
      // Report data request inclusion from Witnet to WitnetRequestBoard
      await this.WitnetRequestBoard.reportDataRequestInclusion(requestId, [drOutputHash], 0, blockHeader, epoch, {
        from: claimer,
      })
    })
    it("fails if reporter is not abs member", async () => {
      await expectRevert(
        this.WitnetRequestBoard.reportResult(requestId, [], 0, blockHeader, epoch, resultHex, { from: other }),
        "Not a member of the ABS"
      )
    })
    it("abs member (claimer) can report a data request result from Witnet (0.5 eth to claimer)", async () => {
      // Initial balances
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
      const claimerBalanceTracker = await balance.tracker(claimer)
      const ownerBalanceTracker = await balance.tracker(owner)
      const contractInitialBalance = await contractBalanceTracker.get()
      const claimerInitialBalance = await claimerBalanceTracker.get()
      // Get the owner balance after posting block
      const ownerInitialBalance = await ownerBalanceTracker.get()

      // Report data request result from Witnet to WitnetRequestBoard
      const reportResultTx = await this.WitnetRequestBoard.reportResult(
        requestId, [], 0, blockHeader, epoch, resultHex,
        { from: claimer, gasPrice: 1 }
      )

      // Check `PostedRequest` event
      expectEvent(
        reportResultTx,
        "PostedResult",
        {
          _from: claimer,
          _id: requestId,
        },
      )
      expect(reportResultTx.logs[0].args._from, "match address of DR creator").to.be.equal(claimer)
      expect(reportResultTx.logs[0].args._id, "match data request id").to.be.bignumber.equal(requestId)

      // Check balances (contract decreased and claimer increased)
      const contractFinalBalance = await contractBalanceTracker.get()
      const claimerFinalBalance = await claimerBalanceTracker.get()
      const ownerFinalBalance = await ownerBalanceTracker.get()

      expect(
        contractFinalBalance.eq(contractInitialBalance
          .sub(ether("0.625"))
        ),
        "contract balance should have decreased after reporting dr request result by 0.625 eth",
      ).to.equal(true)
      expect(
        claimerFinalBalance.eq(claimerInitialBalance
          .add(ether("0.5"))
          .sub(new BN(reportResultTx.receipt.gasUsed)),
        ),
        "claimer balance should have increased after reporting dr request result by 0.5 eth",
      ).to.equal(true)
      expect(
        ownerFinalBalance.eq(ownerInitialBalance
          .add(ether("0.125"))
        ),
        "Owner balance should have increased after reporting b lock by 0.125 eth",
      ).to.equal(true)
    })
  })

  describe("Pushing PoI to 9 levels report data request result", async () => {
    beforeEach(async () => {
      // Post data request
      await this.WitnetRequestBoard.postDataRequest(this.Request.address, ether("0.5"), ether("0.25"), {
        from: requestor,
        value: ether("1"),
      })
      // Claim data request
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const message = data.poe[0].lastBeacon
      const signature = data.signature
      const proof = await this.WitnetRequestBoard.decodeProof(proofBytes)
      const fastVerifyParams = await this.WitnetRequestBoard.computeFastVerifyParams(publicKey, proof, message)
      await this.WitnetRequestBoard.claimDataRequests(
        [requestId],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: claimer,
        })
      const roots = calculateRoots(9, requestHex, resultHex)
      const drInclusionProof = Array(10).fill(drOutputHash)

      // Post new block
      await this.BlockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: owner,
      })
      // Report data request inclusion from Witnet to WitnetRequestBoard
      await this.WitnetRequestBoard.reportDataRequestInclusion(requestId, drInclusionProof, 0, blockHeader, epoch, {
        from: claimer,
      })
    })
    it("abs member (claimer) can report a data request result from Witnet (0.5 eth to claimer)", async () => {
      // Initial balances
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
      const claimerBalanceTracker = await balance.tracker(claimer)
      const contractInitialBalance = await contractBalanceTracker.get()
      const claimerInitialBalance = await claimerBalanceTracker.get()
      const proof = Array(9).fill(drOutputHash)

      // Report data request result from Witnet to WitnetRequestBoard
      const reportResultTx = await this.WitnetRequestBoard.reportResult(
        requestId, proof, 0, blockHeader, epoch, resultHex,
        { from: claimer, gasPrice: 1 }
      )

      // Check `PostedRequest` event
      expectEvent(
        reportResultTx,
        "PostedResult",
        {
          _from: claimer,
          _id: requestId,
        },
      )
      expect(reportResultTx.logs[0].args._from, "match address of DR creator").to.be.equal(claimer)
      expect(reportResultTx.logs[0].args._id, "match data request id").to.be.bignumber.equal(requestId)

      // Check balances (contract decreased and claimer increased)
      const contractFinalBalance = await contractBalanceTracker.get()
      const claimerFinalBalance = await claimerBalanceTracker.get()

      expect(
        contractFinalBalance.eq(contractInitialBalance
          .sub(ether("0.375"))
        ),
        "contract balance should have decreased after reporting dr request result by 0.625 eth",
      ).to.equal(true)
      expect(
        claimerFinalBalance.eq(claimerInitialBalance
          .add(ether("0.25"))
          .sub(new BN(reportResultTx.receipt.gasUsed)),
        ),
        "claimer balance should have increased after reporting dr request result by 0.5 eth",
      ).to.equal(true)
    })
  })

  describe("read data request result", async () => {
    beforeEach(async () => {
      // Post data request
      await this.WitnetRequestBoard.postDataRequest(this.Request.address, ether("0.25"), ether("0.5"), {
        from: requestor,
        value: ether("1"),
      })
      // Claim data request
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const message = data.poe[0].lastBeacon
      const signature = data.signature
      const proof = await this.WitnetRequestBoard.decodeProof(proofBytes)
      const fastVerifyParams = await this.WitnetRequestBoard.computeFastVerifyParams(publicKey, proof, message)
      await this.WitnetRequestBoard.claimDataRequests(
        [requestId],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: claimer,
        })
      // Post new block
      await this.BlockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: owner,
      })
      // Report data request inclusion from Witnet to WitnetRequestBoard
      await this.WitnetRequestBoard.reportDataRequestInclusion(requestId, [drOutputHash], 0, blockHeader, epoch, {
        from: claimer,
      })
      // Report data request result from Witnet to WitnetRequestBoard
      await this.WitnetRequestBoard.reportResult(requestId, [], 0, blockHeader, epoch, resultHex, { from: claimer })
    })
    it("anyone can read the data request result", async () => {
      // Read data request result from WitnetRequestBoard by `requestId`
      const requestResultCall = await this.WitnetRequestBoard.readResult(requestId, { from: requestor })
      expect(requestResultCall).to.be.equal(resultHex)
    })
  })
})
