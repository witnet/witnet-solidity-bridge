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
const roots = calculateRoots(requestHex, resultHex)

// Function to calculate merkle roots for Proof-of-Inclusions (PoI)
function calculateRoots (drBytes, resBytes) {
  let hash = sha256.create()
  hash.update(web3.utils.hexToBytes(drBytes))
  const drHash = "0x" + hash.hex()
  hash = sha256.create()
  hash.update(web3.utils.hexToBytes(drHash))
  hash.update(web3.utils.hexToBytes(drHash))
  const expectedDrHash = "0x" + hash.hex()
  hash = sha256.create()
  hash.update(web3.utils.hexToBytes(expectedDrHash))
  hash.update(web3.utils.hexToBytes(resBytes))
  const expectedResHash = "0x" + hash.hex()
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
  })

  describe("post data request", async () => {
    it("creator can post a data request", async () => {
      // Initial balance
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
      const contractInitialBalance = await contractBalanceTracker.get()

      // Post Data Request
      const postDataRequestTx = await this.WitnetRequestBoard.postDataRequest(requestHex, ether("0.5"), {
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
        },
      )
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
  })

  describe("upgrade data request", async () => {
    beforeEach(async () => {
      await this.WitnetRequestBoard.postDataRequest(requestHex, ether("0.5"), {
        from: requestor,
        value: ether("1"),
      })
    })
    it("creator can upgrade existing data request (1 eth for rewards)", async () => {
      // Initial balance
      const contractBalanceTracker = await balance.tracker(this.WitnetRequestBoard.address)
      const contractInitialBalance = await contractBalanceTracker.get()

      // Update data request (increased rewards)
      await this.WitnetRequestBoard.upgradeDataRequest(requestId, ether("0.5"), {
        from: requestor,
        value: ether("1"),
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
  })

  describe("claim data request", async () => {
    beforeEach(async () => {
      await this.WitnetRequestBoard.postDataRequest(requestHex, ether("0.5"), {
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
      await this.WitnetRequestBoard.postDataRequest(requestHex, ether("0.5"), {
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
      const contractInitialBalance = await contractBalanceTracker.get()
      const claimerInitialBalance = await claimerBalanceTracker.get()

      // Post new block and report data request inclusion
      await this.BlockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: owner,
      })
      await this.WitnetRequestBoard.reportDataRequestInclusion(requestId, [drOutputHash], 0, blockHeader, epoch, {
        from: other,
      })

      // Check balances (contract decreased and claimer increased)
      const contractFinalBalance = await contractBalanceTracker.get()
      const claimerFinalBalance = await claimerBalanceTracker.get()
      expect(
        contractFinalBalance.eq(contractInitialBalance
          .sub(ether("0.5"))
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
      await this.WitnetRequestBoard.postDataRequest(requestHex, ether("0.5"), {
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
      const contractInitialBalance = await contractBalanceTracker.get()
      const claimerInitialBalance = await claimerBalanceTracker.get()

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

      expect(
        contractFinalBalance.eq(contractInitialBalance
          .sub(ether("0.5"))
        ),
        "contract balance should have decreased after reporting dr request result by 0.5 eth",
      ).to.equal(true)
      expect(
        claimerFinalBalance.eq(claimerInitialBalance
          .add(ether("0.5"))
          .sub(new BN(reportResultTx.receipt.gasUsed)),
        ),
        "claimer balance should have increased after reporting dr request result by 0.5 eth",
      ).to.equal(true)
    })
  })

  describe("read data request result", async () => {
    beforeEach(async () => {
      // Post data request
      await this.WitnetRequestBoard.postDataRequest(requestHex, ether("0.5"), {
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
