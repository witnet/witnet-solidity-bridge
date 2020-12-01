const WRB = artifacts.require("WitnetRequestsBoard")
const MockBlockRelay = artifacts.require("MockBlockRelay")
const BlockRelayProxy = artifacts.require("BlockRelayProxy")
const Request = artifacts.require("Request")
const truffleAssert = require("truffle-assertions")
const sha = require("js-sha256")

// Data generated using Witnet ful4n0 identity
const data = require("./data.json")

function calculateRoots (drBytes, resBytes) {
  let hash = sha.sha256.create()
  hash.update(web3.utils.hexToBytes(drBytes))
  const drHash = "0x" + hash.hex()
  hash = sha.sha256.create()
  hash.update(web3.utils.hexToBytes(drHash))
  hash.update(web3.utils.hexToBytes(drHash))
  const expectedDrHash = "0x" + hash.hex()
  hash = sha.sha256.create()
  hash.update(web3.utils.hexToBytes(expectedDrHash))
  hash.update(web3.utils.hexToBytes(resBytes))
  const expectedResHash = "0x" + hash.hex()
  return [expectedDrHash, expectedResHash]
}

contract("WitnetRequestBoard", accounts => {
  describe("WitnetRequestBoard test suite", () => {
    let wrbInstance
    let blockRelay
    let blockRelayProxy
    beforeEach(async () => {
      blockRelay = await MockBlockRelay.new({
        from: accounts[0],
      })
      blockRelayProxy = await BlockRelayProxy.new(blockRelay.address, {
        from: accounts[0],
      })
      wrbInstance = await WRB.new(blockRelayProxy.address, 2)
    })

    it("should post 2 data requests, read them successfully and check balances afterwards", async () => {
      // Take current balance
      const account1 = accounts[0]
      const actualBalance1 = await web3.eth.getBalance(account1)

      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await Request.new(drBytes)

      const drBytes2 = web3.utils.fromAscii("This is a second DR")
      const request2 = await Request.new(drBytes2)

      const halfEther = web3.utils.toWei("0.5", "ether")

      // Post first data request
      const tx1 = wrbInstance.postDataRequest(request.address, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      // Post second data request
      const tx2 = wrbInstance.postDataRequest(request2.address, 0)
      const txHash2 = await waitForHash(tx2)
      const txReceipt2 = await web3.eth.getTransactionReceipt(txHash2)
      const id2 = txReceipt2.logs[0].data

      // Read both
      const readDrBytes = await wrbInstance.readDataRequest.call(id1)
      const readDrBytes2 = await wrbInstance.readDataRequest.call(id2)

      // Assert correct balances
      const afterBalance1 = await web3.eth.getBalance(account1)
      const contractBalanceAfter = await web3.eth.getBalance(
        wrbInstance.address
      )

      assert(parseInt(afterBalance1, 10) < parseInt(actualBalance1, 10))
      assert.equal(web3.utils.toWei("1", "ether"), contractBalanceAfter)

      assert.equal(drBytes, readDrBytes)
      assert.equal(drBytes2, readDrBytes2)
    })

    it("should upgrade the reward of a data request after posting it in the contract", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await Request.new(drBytes)
      const halfEther = web3.utils.toWei("0.5", "ether")

      // post data request
      const tx1 = wrbInstance.postDataRequest(request.address, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      // assert correct balance
      const contractBalanceBefore = await web3.eth.getBalance(
        wrbInstance.address
      )
      assert.equal(web3.utils.toWei("1", "ether"), contractBalanceBefore)

      // upgrade reward (and thus balance of WRB)
      const tx2 = wrbInstance.upgradeDataRequest(id1, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      await waitForHash(tx2)

      // assert correct balance
      const contractBalanceAfter = await web3.eth.getBalance(
        wrbInstance.address
      )

      assert.equal(web3.utils.toWei("2", "ether"), contractBalanceAfter)
    })

    it("should post a data request, claim it, post a new block to block relay, " +
      "verify inclusion and result reporting with PoIs and read the result",
    async () => {
      const account1 = accounts[0]
      const account2 = accounts[1]
      const blockHeader = "0x" + sha.sha256("block header")
      const actualBalance1 = await web3.eth.getBalance(account1)
      const actualBalance2 = await web3.eth.getBalance(account2)

      // Create data requests and roots
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await Request.new(drBytes)
      const drOutputHash = "0x" + sha.sha256(web3.utils.hexToBytes(drBytes))
      const resBytes = web3.utils.fromAscii("This is a result")
      const roots = calculateRoots(drBytes, resBytes)
      const halfEther = web3.utils.toWei("0.5", "ether")
      const epoch = 2

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const proof = await wrbInstance.decodeProof(proofBytes)
      const message = data.poe[0].lastBeacon
      const fastVerifyParams = await wrbInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wrbInstance.postDataRequest(request.address, halfEther, {
        from: account1,
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      // check if data request is claimable
      const claimCheck = await wrbInstance.checkDataRequestsClaimability.call([id1])
      assert.deepEqual([true], claimCheck)

      // claim data request
      const tx2 = wrbInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: account2,
        })
      await waitForHash(tx2)

      // get data request pkhClaim
      const pkhClaim = await wrbInstance.getDataRequestPkhClaim(id1)
      assert.equal(pkhClaim, account2)

      // post new block
      const txRelay = blockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay)

      // report DR inclusion (with PoI)
      const concatenated = web3.utils.hexToBytes(blockHeader).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch), 64
          )
        )
      )
      const beacon = await wrbInstance.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))

      const tx3 = wrbInstance.reportDataRequestInclusion(id1, [drOutputHash], 0, blockHeader, epoch, {
        from: account2,
      })

      // check payment for inclusion
      await waitForHash(tx3)
      const afterBalance2 = await web3.eth.getBalance(account2)
      assert(parseInt(afterBalance2, 10) > parseInt(actualBalance2, 10))

      // report result
      const restx = wrbInstance.reportResult(id1, [], 0, blockHeader, epoch, resBytes, { from: account2 })
      await waitForHash(restx)

      // check payment of result reporting
      const afterBalance1 = await web3.eth.getBalance(account1)
      const balanceFinal = await web3.eth.getBalance(account2)
      const contractBalanceAfter = await web3.eth.getBalance(
        wrbInstance.address
      )

      assert(parseInt(afterBalance1, 10) < parseInt(actualBalance1, 10))
      assert(parseInt(balanceFinal, 10) > parseInt(afterBalance2, 10))

      assert.equal(0, contractBalanceAfter)

      // read result bytes
      const readResBytes = await wrbInstance.readResult.call(id1)
      assert.equal(resBytes, readResBytes)
    })

    it("should post two data requests and ensure Ids are as expected", async () => {
      const drBytes1 = web3.utils.fromAscii("This is a DR")
      const request1 = await Request.new(drBytes1)
      const drBytes2 = web3.utils.fromAscii("This is a second DR")
      const request2 = await Request.new(drBytes2)
      const halfEther = web3.utils.toWei("0.5", "ether")

      // post the first data request
      const tx1 = wrbInstance.postDataRequest(request1.address, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)

      // retrieve the id of the first data request posted
      const id1 = txReceipt1.logs[0].data
      assert.equal(web3.utils.hexToNumberString(id1), web3.utils.hexToNumberString("0x1"))

      // post the second data request
      const tx2 = wrbInstance.postDataRequest(request2.address, 0)
      const txHash2 = await waitForHash(tx2)
      const txReceipt2 = await web3.eth.getTransactionReceipt(txHash2)

      // retrieve the id of the second data request posted
      const id2 = txReceipt2.logs[0].data
      assert.equal(web3.utils.hexToNumberString(id2), web3.utils.hexToNumberString("0x2"))

      // read the bytes of both
      const readDrBytes1 = await wrbInstance.readDataRequest.call(id1)
      const readDrBytes2 = await wrbInstance.readDataRequest.call(id2)
      assert.equal(drBytes1, readDrBytes1)
      assert.equal(drBytes2, readDrBytes2)
    })

    it("should check the emission of the PostedRequest event with correct id", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await Request.new(drBytes)
      const hash = "0x1"
      const expectedResultId = web3.utils.hexToNumberString(hash)

      // post data request
      const tx = await wrbInstance.postDataRequest(request.address, 0)

      // check emission of the event and its id correctness
      truffleAssert.eventEmitted(tx, "PostedRequest", (ev) => {
        return ev[1].toString() === expectedResultId
      })

      // Finally read the bytes
      const readDrBytes = await wrbInstance.readDataRequest.call(expectedResultId)
      assert.equal(drBytes, readDrBytes)
    })

    it("should insert a data request, subscribe to the PostedResult event, wait for its emission, " +
      "perform the claim, post new block, report dr inclusion and the result " +
      "and only then read result", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await Request.new(drBytes)
      const data1 = "0x" + sha.sha256(web3.utils.hexToBytes(drBytes))
      const resBytes = web3.utils.fromAscii("This is a result")
      const halfEther = web3.utils.toWei("0.5", "ether")

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[1].proof
      const proof = await wrbInstance.decodeProof(proofBytes)
      const message = data.poe[1].lastBeacon
      const fastVerifyParams = await wrbInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wrbInstance.postDataRequest(request.address, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data
      assert.equal(web3.utils.hexToNumberString(id1), web3.utils.hexToNumberString("0x1"))

      const blockHeader = "0x" + sha.sha256("block header")
      const roots = calculateRoots(drBytes, resBytes)
      const epoch = 2
      const txRelay = blockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay)

      // claim data request
      const tx2 = wrbInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: accounts[1],
        })
      await waitForHash(tx2)

      // report data request inclusion
      const tx3 = wrbInstance.reportDataRequestInclusion(id1, [data1], 0, blockHeader, epoch, {
        from: accounts[1],
      })
      await waitForHash(tx3)

      // report result
      const tx4 = await wrbInstance.reportResult(id1, [], 0, blockHeader, epoch, resBytes, {
        from: accounts[1],
      })

      truffleAssert.eventEmitted(tx4, "PostedResult", (ev) => {
        return ev[1].eq(web3.utils.toBN(id1))
      })
    })

    it("should revert the transaction when trying to read from a non-existent block", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await Request.new(drBytes)
      const resBytes = web3.utils.fromAscii("This is a result")
      const halfEther = web3.utils.toWei("0.5", "ether")
      const fakeBlockHeader = "0x" + sha.sha256("fake block header")
      const dummySibling = 1

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[1].proof
      const proof = await wrbInstance.decodeProof(proofBytes)
      const message = data.poe[1].lastBeacon
      const fastVerifyParams = await wrbInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wrbInstance.postDataRequest(request.address, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data
      assert.equal(web3.utils.hexToNumberString(id1), web3.utils.hexToNumberString("0x1"))

      const blockHeader = "0x" + sha.sha256("block header")
      const roots = calculateRoots(drBytes, resBytes)
      const epoch = 2
      const txRelay = blockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay)

      // claim data request
      const tx2 = wrbInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: accounts[1],
        })
      await waitForHash(tx2)

      // should fail to read blockhash from a non-existing block
      await truffleAssert.reverts(
        wrbInstance.reportDataRequestInclusion(id1, [dummySibling], 2, fakeBlockHeader, epoch, {
          from: accounts[1],
        }), "Non-existing block")
    })

    it("should revert because the rewards are higher than the values sent. " +
      "Checks the post data request transaction",
    async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await Request.new(drBytes)

      // assert it reverts when rewards are higher than values sent
      await truffleAssert.reverts(wrbInstance.postDataRequest(request.address, web3.utils.toWei("2", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      }), "Transaction value needs to be equal or greater than tally reward")
    })

    it("should revert because the rewards are higher than the values sent. " +
      "Checks the upgrade data request transaction",
    async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const request = await Request.new(drBytes)

      // this should pass
      const tx1 = wrbInstance.postDataRequest(request.address, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      // assert it reverts when rewards are higher than values sent
      await truffleAssert.reverts(wrbInstance.upgradeDataRequest(id1, web3.utils.toWei("2", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      }), "Transaction value needs to be equal or greater than tally reward")
    })

    it("should revert when trying to claim a DR that was already claimed", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR4")
      const request = await Request.new(drBytes)
      const resBytes = web3.utils.fromAscii("This is a result")

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[1].proof
      const proof = await wrbInstance.decodeProof(proofBytes)
      const message = data.poe[1].lastBeacon
      const fastVerifyParams = await wrbInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wrbInstance.postDataRequest(request.address, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      const blockHeader = "0x" + sha.sha256("block header")
      const roots = calculateRoots(drBytes, resBytes)
      const epoch = 2
      const txRelay = blockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay)

      // claim data request
      const tx2 = wrbInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: accounts[1],
        })
      await waitForHash(tx2)

      // check if data request is not claimable
      const claimCheck = await wrbInstance.checkDataRequestsClaimability.call([id1])
      assert.deepEqual([false], claimCheck)

      // should revert when trying to claim it again
      await truffleAssert.reverts(
        wrbInstance.claimDataRequests(
          [id1],
          proof,
          publicKey,
          fastVerifyParams[0],
          fastVerifyParams[1],
          signature, {
            from: accounts[1],
          }),
        "One of the listed data requests was already claimed")
    })

    it("should revert when trying to report a dr inclusion that has not been claimed", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR5")
      const request = await Request.new(drBytes)
      const resBytes = web3.utils.fromAscii("This is a result")
      const dummySybling = 1
      const epoch = 0

      // post data request
      const tx1 = wrbInstance.postDataRequest(request.address, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      const blockHeader1 = "0x" + sha.sha256("block header")
      const roots1 = calculateRoots(drBytes, resBytes)
      const epoch1 = 2
      const txRelay1 = blockRelay.postNewBlock(blockHeader1, epoch1, roots1[0], roots1[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay1)

      // Should revert when reporting the inclusion since the dr has not been claimed
      await truffleAssert.reverts(wrbInstance.reportDataRequestInclusion(id1, [dummySybling], 1, blockHeader1, epoch, {
        from: accounts[1],
      }), "Data Request has not yet been claimed")
    })

    it("should revert when trying to report a dr inclusion that was already reported", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR5")
      const request = await Request.new(drBytes)
      const resBytes = web3.utils.fromAscii("This is a result")
      const data1 = "0x" + sha.sha256(web3.utils.hexToBytes(drBytes))
      const dummySybling = 1

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[1].proof
      const proof = await wrbInstance.decodeProof(proofBytes)
      const message = data.poe[1].lastBeacon
      const fastVerifyParams = await wrbInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wrbInstance.postDataRequest(request.address, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      const blockHeader1 = "0x" + sha.sha256("block header")
      const roots1 = calculateRoots(drBytes, resBytes)
      const epoch1 = 2
      const txRelay1 = blockRelay.postNewBlock(blockHeader1, epoch1, roots1[0], roots1[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay1)

      // claim data request
      const tx2 = wrbInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: accounts[1],
        })
      await waitForHash(tx2)

      const blockHeader2 = "0x" + sha.sha256("block header 2")
      const roots2 = calculateRoots(drBytes, resBytes)
      const epoch2 = 3
      const txRelay2 = blockRelay.postNewBlock(blockHeader2, epoch2, roots2[0], roots2[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay2)

      const concatenated = web3.utils.hexToBytes(blockHeader2).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch2), 64
          )
        )
      )
      const beacon = await wrbInstance.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))

      // post data request inclusion
      const tx3 = wrbInstance.reportDataRequestInclusion(id1, [data1], 0, blockHeader2, epoch1, {
        from: accounts[0],
      })
      await waitForHash(tx3)

      // assert it fails when trying to report the dr inclusion again
      await truffleAssert.reverts(wrbInstance.reportDataRequestInclusion(id1, [dummySybling], 1, blockHeader2, epoch1, {
        from: accounts[1],
      }), "DR already included")
    })

    it("should revert when trying to prove inclusion of a DR in an epoch inferior than" +
      "the one in which DR was posted", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR5")
      const request = await Request.new(drBytes)
      const resBytes = web3.utils.fromAscii("This is a result")
      const data1 = "0x" + sha.sha256(web3.utils.hexToBytes(drBytes))

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[1].proof
      const proof = await wrbInstance.decodeProof(proofBytes)
      const message = data.poe[1].lastBeacon
      const fastVerifyParams = await wrbInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // when posting this block, the lastBlock.epoch in the blockRelay will be 1
      const blockHeader0 = "0x" + sha.sha256("block header 0")
      const roots0 = calculateRoots(drBytes, resBytes)
      const epoch0 = 1
      const txRelay0 = blockRelay.postNewBlock(blockHeader0, epoch0, roots0[0], roots0[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay0)

      // post data request
      const tx1 = wrbInstance.postDataRequest(request.address, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      const blockHeader1 = "0x" + sha.sha256("block header")
      const roots1 = calculateRoots(drBytes, resBytes)
      const epoch1 = 2
      const txRelay1 = blockRelay.postNewBlock(blockHeader1, epoch1, roots1[0], roots1[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay1)

      // claim data request
      const tx2 = wrbInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: accounts[1],
        })
      await waitForHash(tx2)

      const blockHeader2 = "0x" + sha.sha256("block header 2")
      const roots2 = calculateRoots(drBytes, resBytes)
      const epoch2 = 3
      const txRelay2 = blockRelay.postNewBlock(blockHeader2, epoch2, roots2[0], roots2[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay2)

      // assert it fails when trying to report the dr inclusion for an epoch not
      // later than the epoch for which the dr was posted
      await truffleAssert.reverts(wrbInstance.reportDataRequestInclusion(id1, [data1], 0, blockHeader1, 0, {
        from: accounts[0],
      }), "The request inclusion must be reported after it is posted into the WRB")
    })

    it("should revert when reporting a result for a dr for which its inclusion was not reported yet", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR6")
      const request = await Request.new(drBytes)
      const resBytes = web3.utils.fromAscii("This is a result")
      const dummySybling = 1

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[1].proof
      const proof = await wrbInstance.decodeProof(proofBytes)
      const message = data.poe[1].lastBeacon
      const fastVerifyParams = await wrbInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wrbInstance.postDataRequest(request.address, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      const blockHeader = "0x" + sha.sha256("block header")
      const roots = calculateRoots(drBytes, resBytes)
      const epoch = 2
      const txRelay = blockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay)

      // claim data request
      const tx2 = wrbInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: accounts[1],
        })
      await waitForHash(tx2)

      // assert reporting a result when inclusion has not been proved fails
      await truffleAssert.reverts(
        wrbInstance.reportResult(id1, [dummySybling], 1, blockHeader, epoch, resBytes, { from: accounts[1] }),
        "DR not yet included"
      )
    })

    it("should revert because of reporting a result for a data request " +
      "for which a result has been already reported",
    async () => {
      const drBytes = web3.utils.fromAscii("This is a DR7")
      const request = await Request.new(drBytes)
      const resBytes = web3.utils.fromAscii("This is a result")
      const data1 = "0x" + sha.sha256(web3.utils.hexToBytes(drBytes))

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const proof = await wrbInstance.decodeProof(proofBytes)
      const message = data.poe[0].lastBeacon
      const fastVerifyParams = await wrbInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wrbInstance.postDataRequest(request.address, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      // claim data request
      const tx2 = wrbInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: accounts[1],
        })
      await waitForHash(tx2)

      const blockHeader2 = "0x" + sha.sha256("block header")
      const roots2 = calculateRoots(drBytes, resBytes)
      const epoch2 = 2

      // post new block
      const txRelay2 = blockRelay.postNewBlock(blockHeader2, epoch2, roots2[0], roots2[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay2)

      const concatenated = web3.utils.hexToBytes(blockHeader2).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch2), 64
          )
        )
      )
      const beacon = await wrbInstance.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))

      // report data request inclusion
      const tx3 = wrbInstance.reportDataRequestInclusion(id1, [data1], 0, blockHeader2, epoch2, {
        from: accounts[1],
      })
      await waitForHash(tx3)

      // report result
      const tx4 = wrbInstance.reportResult(id1, [], 0, blockHeader2, epoch2, resBytes, {
        from: accounts[1],
      })
      await waitForHash(tx4)

      // revert when reporting the same result
      await truffleAssert.reverts(
        wrbInstance.reportResult(id1, [], 1, blockHeader2, epoch2, resBytes, { from: accounts[0] }),
        "Result already included"
      )
    })

    it("should revert when trying to report the result of a DR in an epoch" +
       " inferior than the one in which DR inclusion was reported ",
    async () => {
      const drBytes = web3.utils.fromAscii("This is a DR7")
      const request = await Request.new(drBytes)
      const resBytes = web3.utils.fromAscii("This is a result")
      const data1 = "0x" + sha.sha256(web3.utils.hexToBytes(drBytes))

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const proof = await wrbInstance.decodeProof(proofBytes)
      const message = data.poe[0].lastBeacon
      const fastVerifyParams = await wrbInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wrbInstance.postDataRequest(request.address, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      // claim data request
      const tx2 = wrbInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: accounts[1],
        })
      await waitForHash(tx2)

      const blockHeader2 = "0x" + sha.sha256("block header")
      const roots2 = calculateRoots(drBytes, resBytes)
      const epoch2 = 2

      // post new block
      const txRelay2 = blockRelay.postNewBlock(blockHeader2, epoch2, roots2[0], roots2[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay2)

      const concatenated = web3.utils.hexToBytes(blockHeader2).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch2), 64
          )
        )
      )
      const beacon = await wrbInstance.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))

      // report data request inclusion
      const tx3 = wrbInstance.reportDataRequestInclusion(id1, [data1], 0, blockHeader2, epoch2, {
        from: accounts[1],
      })
      await waitForHash(tx3)

      // revert when reporting the result for an epoch inferior than the one of the dr inclusion
      await truffleAssert.reverts(
        wrbInstance.reportResult(id1, [], 1, blockHeader2, 0, resBytes, { from: accounts[1] }),
        "The result cannot be reported before the request is included"
      )
    })

    it("should revert because trying to report a result from an address " +
       "that does not belong to the ABS",
    async () => {
      const drBytes = web3.utils.fromAscii("This is a DR7")
      const request = await Request.new(drBytes)
      const resBytes = web3.utils.fromAscii("This is a result")
      const data1 = "0x" + sha.sha256(web3.utils.hexToBytes(drBytes))

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const proof = await wrbInstance.decodeProof(proofBytes)
      const message = data.poe[0].lastBeacon
      const fastVerifyParams = await wrbInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wrbInstance.postDataRequest(request.address, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      // claim data request
      const tx2 = wrbInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: accounts[1],
        })
      await waitForHash(tx2)

      const blockHeader2 = "0x" + sha.sha256("block header")
      const roots2 = calculateRoots(drBytes, resBytes)
      const epoch2 = 2

      // post new block
      const txRelay2 = blockRelay.postNewBlock(blockHeader2, epoch2, roots2[0], roots2[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay2)

      const concatenated = web3.utils.hexToBytes(blockHeader2).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch2), 64
          )
        )
      )
      const beacon = await wrbInstance.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))

      // report data request inclusion
      const tx3 = wrbInstance.reportDataRequestInclusion(id1, [data1], 0, blockHeader2, epoch2, {
        from: accounts[1],
      })
      await waitForHash(tx3)

      // revert when reporting the result beacouse accounts[0] is not a member of the ABS
      await truffleAssert.reverts(
        wrbInstance.reportResult(id1, [], 1, blockHeader2, epoch2, resBytes, { from: accounts[0] }),
        "Not a member of the ABS"
      )
    })

    it("should revert because of trying to claim with an invalid signature",
      async () => {
        const drBytes = web3.utils.fromAscii("This is a DR7")
        const request = await Request.new(drBytes)

        // VRF params
        const publicKey = [data.publicKey.x, data.publicKey.y]
        const proofBytes = data.poe[0].proof
        const proof = await wrbInstance.decodeProof(proofBytes)
        const message = data.poe[0].lastBeacon
        const fastVerifyParams = await wrbInstance.computeFastVerifyParams(publicKey, proof, message)
        const signature = web3.utils.fromAscii("this is a fake sig")

        // post data request
        const tx1 = wrbInstance.postDataRequest(request.address, web3.utils.toWei("1", "ether"), {
          from: accounts[0],
          value: web3.utils.toWei("1", "ether"),
        })
        const txHash1 = await waitForHash(tx1)
        const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
        const id1 = txReceipt1.logs[0].data

        // revert when reporting the same result
        await truffleAssert.reverts(wrbInstance.claimDataRequests(
          [id1],
          proof,
          publicKey,
          fastVerifyParams[0],
          fastVerifyParams[1],
          signature, { from: accounts[1] }), "Not a valid signature")
      })

    it("should update ABS activity",
      async () => {
        const block = await web3.eth.getBlock("latest")

        // update activity
        const tx1 = wrbInstance.updateAbsActivity(block.number)
        await waitForHash(tx1)
      })

    it("should revert updating ABS activity with a future block",
      async () => {
        const block = await web3.eth.getBlock("latest")
        await truffleAssert.reverts(
          wrbInstance.updateAbsActivity(block.number + 100),
          "The provided block number has not been reached"
        )
      })

    it("should revert updating ABS activity with a past block",
      async () => {
        const block = await web3.eth.getBlock("latest")
        const newBlock = 49
        const tx1 = wrbInstance.updateAbsActivity(block.number)
        await waitForHash(tx1)
        await truffleAssert.reverts(
          wrbInstance.updateAbsActivity(newBlock),
          "The provided block is older than the last updated block"
        )
      })

    it("should revert while upgrading the rewards with wrong values or if the result was reported",
      async () => {
        const drBytes = web3.utils.fromAscii("This is a DR7")
        const request = await Request.new(drBytes)
        const resBytes = web3.utils.fromAscii("This is a result")
        const data1 = "0x" + sha.sha256(web3.utils.hexToBytes(drBytes))

        // VRF params
        const publicKey = [data.publicKey.x, data.publicKey.y]
        const proofBytes = data.poe[0].proof
        const proof = await wrbInstance.decodeProof(proofBytes)
        const message = data.poe[0].lastBeacon
        const fastVerifyParams = await wrbInstance.computeFastVerifyParams(publicKey, proof, message)
        const signature = data.signature

        // post data request
        const tx1 = wrbInstance.postDataRequest(request.address, web3.utils.toWei("1", "ether"), {
          from: accounts[0],
          value: web3.utils.toWei("1", "ether"),
        })
        const txHash1 = await waitForHash(tx1)
        const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
        const id1 = txReceipt1.logs[0].data

        // claim data request
        const tx2 = wrbInstance.claimDataRequests(
          [id1],
          proof,
          publicKey,
          fastVerifyParams[0],
          fastVerifyParams[1],
          signature, {
            from: accounts[1],
          })
        await waitForHash(tx2)

        const blockHeader2 = "0x" + sha.sha256("block header")
        const roots2 = calculateRoots(drBytes, resBytes)
        const epoch2 = 2

        // post new block
        const txRelay2 = blockRelay.postNewBlock(blockHeader2, epoch2, roots2[0], roots2[1], {
          from: accounts[0],
        })
        await waitForHash(txRelay2)

        // revert when upgrading data request with wrong rewards and the DR is not yet included
        await truffleAssert.reverts(
          wrbInstance.upgradeDataRequest(
            id1,
            web3.utils.toWei("2", "ether"),
            { from: accounts[1], value: web3.utils.toWei("1", "ether") }
          ),
          "Transaction value needs to be equal or greater than tally reward"
        )

        // report data request inclusion
        const tx3 = wrbInstance.reportDataRequestInclusion(id1, [data1], 0, blockHeader2, epoch2, {
          from: accounts[0],
        })
        await waitForHash(tx3)

        // revert when upgrading data request with wrong rewards and the DR is already included
        await truffleAssert.reverts(
          wrbInstance.upgradeDataRequest(
            id1,
            web3.utils.toWei("1", "ether"),
            { from: accounts[1], value: web3.utils.toWei("2", "ether") }
          ),
          "Txn value should equal result reward argument (request reward already paid)"
        )

        // upgrade data request with valid rewards with DR already included
        const tx4 = wrbInstance.upgradeDataRequest(id1,
          web3.utils.toWei("1", "ether"),
          { from: accounts[0], value: web3.utils.toWei("1", "ether") }
        )
        await waitForHash(tx4)

        // report result
        const tx5 = wrbInstance.reportResult(id1, [], 0, blockHeader2, epoch2, resBytes, { from: accounts[1] })
        await waitForHash(tx5)

        // revert when upgrading data request but the DR result was already reported
        await truffleAssert.reverts(
          wrbInstance.upgradeDataRequest(
            id1,
            web3.utils.toWei("1", "ether"),
            { from: accounts[1], value: web3.utils.toWei("1", "ether") }
          ),
          "Result already included"
        )
      }
    )

    it("should revert reading data for non-existent Ids",
      async () => {
        // revert when reporting the same result
        await truffleAssert.reverts(wrbInstance.readDataRequest(2000), "Id not found")
        await truffleAssert.reverts(wrbInstance.readDrHash(2000), "Id not found")
        await truffleAssert.reverts(wrbInstance.readResult(2000), "Id not found")
      })
  })
})

const waitForHash = txQ =>
  new Promise((resolve, reject) =>
    txQ.on("transactionHash", resolve).catch(reject)
  )
