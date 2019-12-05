const WBI = artifacts.require("WitnetBridgeInterface")
const BlockRelay = artifacts.require("BlockRelay")
const truffleAssert = require("truffle-assertions")
const sha = require("js-sha256")

const data = require("./data.json")

var wait = ms => new Promise((resolve, reject) => setTimeout(resolve, ms))

function calculateRoots (drBytes, resBytes) {
  var hash = sha.sha256.create()
  hash.update(web3.utils.hexToBytes(drBytes))
  var drHash = "0x" + hash.hex()
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

contract("WBI", accounts => {
  describe("WBI test suite", () => {
    let wbiInstance
    let blockRelay
    beforeEach(async () => {
      blockRelay = await BlockRelay.new()
      wbiInstance = await WBI.new(blockRelay.address, 2)
    })

    it("should post 2 data requests, read them successfully and check balances afterwards", async () => {
      // Take current balance
      var account1 = accounts[0]
      const actualBalance1 = await web3.eth.getBalance(account1)

      const drBytes = web3.utils.fromAscii("This is a DR")
      const drBytes2 = web3.utils.fromAscii("This is a second DR")

      const halfEther = web3.utils.toWei("0.5", "ether")

      // Post first data request
      const tx1 = wbiInstance.postDataRequest(drBytes, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      // Post second data request
      const tx2 = wbiInstance.postDataRequest(drBytes2, 0)
      const txHash2 = await waitForHash(tx2)
      const txReceipt2 = await web3.eth.getTransactionReceipt(txHash2)
      const id2 = txReceipt2.logs[0].data

      // Read both
      const readDrBytes = await wbiInstance.readDataRequest.call(id1)
      const readDrBytes2 = await wbiInstance.readDataRequest.call(id2)

      // Assert correct balances
      const afterBalance1 = await web3.eth.getBalance(account1)
      const contractBalanceAfter = await web3.eth.getBalance(
        wbiInstance.address
      )

      assert(parseInt(afterBalance1, 10) < parseInt(actualBalance1, 10))
      assert.equal(web3.utils.toWei("1", "ether"), contractBalanceAfter)

      assert.equal(drBytes, readDrBytes)
      assert.equal(drBytes2, readDrBytes2)
    })
    it("should upgrade the reward of a data request after posting it in the contract", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const halfEther = web3.utils.toWei("0.5", "ether")

      // post data request
      const tx1 = wbiInstance.postDataRequest(drBytes, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      // assert correct balance
      const contractBalanceBefore = await web3.eth.getBalance(
        wbiInstance.address
      )
      assert.equal(web3.utils.toWei("1", "ether"), contractBalanceBefore)

      // upgrade reward (and thus balance of WBI)
      const tx2 = wbiInstance.upgradeDataRequest(id1, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      await waitForHash(tx2)

      // assert correct balance
      const contractBalanceAfter = await web3.eth.getBalance(
        wbiInstance.address
      )

      assert.equal(web3.utils.toWei("2", "ether"), contractBalanceAfter)
    })

    it("should post a data request, claim it, post a new block to block relay, " +
       "verify inclusion and result reporting with PoIs and read the result",
    async () => {
      var account1 = accounts[0]
      var account2 = accounts[1]
      var blockHeader = "0x" + sha.sha256("block header")
      const actualBalance1 = await web3.eth.getBalance(account1)
      const actualBalance2 = await web3.eth.getBalance(account2)

      // Create data requests and roots
      const drBytes = web3.utils.fromAscii("This is a DR")
      const drOutputHash = "0x" + sha.sha256(web3.utils.hexToBytes(drBytes))
      const resBytes = web3.utils.fromAscii("This is a result")
      const roots = calculateRoots(drBytes, resBytes)
      const halfEther = web3.utils.toWei("0.5", "ether")
      const epoch = 2

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const proof = await wbiInstance.decodeProof(proofBytes)
      const message = data.poe[0].lastBeacon
      const fastVerifyParams = await wbiInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wbiInstance.postDataRequest(drBytes, halfEther, {
        from: account1,
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      // check if data request is claimable
      const claimCheck = await wbiInstance.checkDataRequestsClaimability.call([id1])
      assert.deepEqual([true], claimCheck)

      // claim data request
      const tx2 = wbiInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: account2,
        })
      await waitForHash(tx2)

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
      const beacon = await wbiInstance.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))

      const tx3 = wbiInstance.reportDataRequestInclusion(id1, [drOutputHash], 0, blockHeader, {
        from: account2,
      })

      // check payment for inclusion
      await waitForHash(tx3)
      const afterBalance2 = await web3.eth.getBalance(account2)
      assert(parseInt(afterBalance2, 10) > parseInt(actualBalance2, 10))

      // report result
      const restx = wbiInstance.reportResult(id1, [], 0, blockHeader, resBytes, { from: account2 })
      await waitForHash(restx)

      // check payment of result reporting
      const afterBalance1 = await web3.eth.getBalance(account1)
      const balanceFinal = await web3.eth.getBalance(account2)
      const contractBalanceAfter = await web3.eth.getBalance(
        wbiInstance.address
      )

      assert(parseInt(afterBalance1, 10) < parseInt(actualBalance1, 10))
      assert(parseInt(balanceFinal, 10) > parseInt(afterBalance2, 10))

      assert.equal(0, contractBalanceAfter)

      // read result bytes
      const readResBytes = await wbiInstance.readResult.call(id1)
      assert.equal(resBytes, readResBytes)
    })

    it("should post two data requests and ensure Ids are as expected", async () => {
      const drBytes1 = web3.utils.fromAscii("This is a DR")
      const drBytes2 = web3.utils.fromAscii("This is a second DR")
      const halfEther = web3.utils.toWei("0.5", "ether")

      // post the first data request
      const tx1 = wbiInstance.postDataRequest(drBytes1, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)

      // retrieve the id of the first data request posted
      const id1 = txReceipt1.logs[0].data
      assert.equal(web3.utils.hexToNumberString(id1), web3.utils.hexToNumberString("0x1"))

      // post the second data request
      const tx2 = wbiInstance.postDataRequest(drBytes2, 0)
      const txHash2 = await waitForHash(tx2)
      const txReceipt2 = await web3.eth.getTransactionReceipt(txHash2)

      // retrieve the id of the second data request posted
      const id2 = txReceipt2.logs[0].data
      assert.equal(web3.utils.hexToNumberString(id2), web3.utils.hexToNumberString("0x2"))

      // read the bytes of both
      const readDrBytes1 = await wbiInstance.readDataRequest.call(id1)
      const readDrBytes2 = await wbiInstance.readDataRequest.call(id2)
      assert.equal(drBytes1, readDrBytes1)
      assert.equal(drBytes2, readDrBytes2)
    })

    it("should check the emission of the PostedRequest event with correct id", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const hash = "0x1"
      const expectedResultId = web3.utils.hexToNumberString(hash)

      // post data request
      const tx = await wbiInstance.postDataRequest(drBytes, 0)

      // check emission of the event and its id correctness
      truffleAssert.eventEmitted(tx, "PostedRequest", (ev) => {
        return ev[1].toString() === expectedResultId
      })

      // Finally read the bytes
      const readDrBytes = await wbiInstance.readDataRequest.call(expectedResultId)
      assert.equal(drBytes, readDrBytes)
    })

    it("should insert a data request, subscribe to the PostedResult event, wait for its emission, " +
       "perform the claim, post new block, report dr inclusion and the result " +
       "and only then read result", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const data1 = "0x" + sha.sha256(web3.utils.hexToBytes(drBytes))
      const resBytes = web3.utils.fromAscii("This is a result")
      const halfEther = web3.utils.toWei("0.5", "ether")

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[1].proof
      const proof = await wbiInstance.decodeProof(proofBytes)
      const message = data.poe[1].lastBeacon
      const fastVerifyParams = await wbiInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wbiInstance.postDataRequest(drBytes, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data
      assert.equal(web3.utils.hexToNumberString(id1), web3.utils.hexToNumberString("0x1"))

      // subscribe to PostedResult event
      wbiInstance.PostedResult({}, async (_error, event) => {
        const readresBytes1 = await wbiInstance.readResult.call(id1)
        assert.equal(resBytes, readresBytes1)
      })

      var blockHeader = "0x" + sha.sha256("block header")
      const roots = calculateRoots(drBytes, resBytes)
      const epoch = 2
      const txRelay = blockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay)

      // claim data request
      const tx2 = wbiInstance.claimDataRequests(
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
      const tx3 = wbiInstance.reportDataRequestInclusion(id1, [data1], 0, blockHeader, {
        from: accounts[1],
      })
      await waitForHash(tx3)

      // report result
      const tx4 = await wbiInstance.reportResult(id1, [], 0, blockHeader, resBytes, {
        from: accounts[2],
      })

      // wait for the async method to finish
      await wait(500)

      truffleAssert.eventEmitted(tx4, "PostedResult", (ev) => {
        return ev[1].eq(web3.utils.toBN(id1))
      })
    })

    it("should revert the transaction when trying to read from a non-existent block", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")
      const resBytes = web3.utils.fromAscii("This is a result")
      const halfEther = web3.utils.toWei("0.5", "ether")
      var fakeBlockHeader = "0x" + sha.sha256("fake block header")
      var dummySibling = 1

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[1].proof
      const proof = await wbiInstance.decodeProof(proofBytes)
      const message = data.poe[1].lastBeacon
      const fastVerifyParams = await wbiInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wbiInstance.postDataRequest(drBytes, halfEther, {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data
      assert.equal(web3.utils.hexToNumberString(id1), web3.utils.hexToNumberString("0x1"))

      var blockHeader = "0x" + sha.sha256("block header")
      const roots = calculateRoots(drBytes, resBytes)
      const epoch = 2
      const txRelay = blockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay)

      // claim data request
      const tx2 = wbiInstance.claimDataRequests(
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
      await truffleAssert.reverts(wbiInstance.reportDataRequestInclusion(id1, [dummySibling], 2, fakeBlockHeader, {
        from: accounts[1],
      }), "Non-existing block")
    })
    it("should revert because the rewards are higher than the values sent. " +
       "Checks the post data request transaction",
    async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")

      // assert it reverts when rewards are higher than values sent
      await truffleAssert.reverts(wbiInstance.postDataRequest(drBytes, web3.utils.toWei("2", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      }), "Transaction value needs to be equal or greater than tally reward")
    })
    it("should revert because the rewards are higher than the values sent. " +
       "Checks the upgrade data request transaction",
    async () => {
      const drBytes = web3.utils.fromAscii("This is a DR")

      // this should pass
      const tx1 = wbiInstance.postDataRequest(drBytes, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      // assert it reverts when rewards are higher than values sent
      await truffleAssert.reverts(wbiInstance.upgradeDataRequest(id1, web3.utils.toWei("2", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      }), "Transaction value needs to be equal or greater than tally reward")
    })

    it("should revert when trying to claim a DR that was already claimed", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR4")
      const resBytes = web3.utils.fromAscii("This is a result")

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[1].proof
      const proof = await wbiInstance.decodeProof(proofBytes)
      const message = data.poe[1].lastBeacon
      const fastVerifyParams = await wbiInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wbiInstance.postDataRequest(drBytes, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      var blockHeader = "0x" + sha.sha256("block header")
      const roots = calculateRoots(drBytes, resBytes)
      const epoch = 2
      const txRelay = blockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay)

      // claim data request
      const tx2 = wbiInstance.claimDataRequests(
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
      const claimCheck = await wbiInstance.checkDataRequestsClaimability.call([id1])
      assert.deepEqual([false], claimCheck)

      // should revert when trying to claim it again
      await truffleAssert.reverts(
        wbiInstance.claimDataRequests(
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

    it("should revert when trying to report a dr inclusion that was already reported", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR5")
      const resBytes = web3.utils.fromAscii("This is a result")
      const data1 = "0x" + sha.sha256(web3.utils.hexToBytes(drBytes))
      var dummySybling = 1

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[1].proof
      const proof = await wbiInstance.decodeProof(proofBytes)
      const message = data.poe[1].lastBeacon
      const fastVerifyParams = await wbiInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wbiInstance.postDataRequest(drBytes, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      var blockHeader1 = "0x" + sha.sha256("block header")
      const roots1 = calculateRoots(drBytes, resBytes)
      const epoch1 = 2
      const txRelay1 = blockRelay.postNewBlock(blockHeader1, epoch1, roots1[0], roots1[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay1)

      // claim data request
      const tx2 = wbiInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: accounts[1],
        })
      await waitForHash(tx2)

      var blockHeader2 = "0x" + sha.sha256("block header 2")
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
      const beacon = await wbiInstance.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))

      // post data request inclusion
      const tx3 = wbiInstance.reportDataRequestInclusion(id1, [data1], 0, blockHeader2, {
        from: accounts[0],
      })
      await waitForHash(tx3)

      // assert it fails when trying to report the dr inclusion again
      await truffleAssert.reverts(wbiInstance.reportDataRequestInclusion(id1, [dummySybling], 1, blockHeader2, {
        from: accounts[1],
      }), "DR already included")
    })

    it("should revert when reporting a result for a dr for which its inclusion was not reported yet", async () => {
      const drBytes = web3.utils.fromAscii("This is a DR6")
      const resBytes = web3.utils.fromAscii("This is a result")
      var dummySybling = 1

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[1].proof
      const proof = await wbiInstance.decodeProof(proofBytes)
      const message = data.poe[1].lastBeacon
      const fastVerifyParams = await wbiInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wbiInstance.postDataRequest(drBytes, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      var blockHeader = "0x" + sha.sha256("block header")
      const roots = calculateRoots(drBytes, resBytes)
      const epoch = 2
      const txRelay = blockRelay.postNewBlock(blockHeader, epoch, roots[0], roots[1], {
        from: accounts[0],
      })
      await waitForHash(txRelay)

      // claim data request
      const tx2 = wbiInstance.claimDataRequests(
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
        wbiInstance.reportResult(id1, [dummySybling], 1, blockHeader, resBytes, { from: accounts[1] }),
        "DR not yet included"
      )
    })
    it("should revert because of reporting a result for a data request " +
       "for which a result has been already reported",
    async () => {
      const drBytes = web3.utils.fromAscii("This is a DR7")
      const resBytes = web3.utils.fromAscii("This is a result")
      const data1 = "0x" + sha.sha256(web3.utils.hexToBytes(drBytes))

      // VRF params
      const publicKey = [data.publicKey.x, data.publicKey.y]
      const proofBytes = data.poe[0].proof
      const proof = await wbiInstance.decodeProof(proofBytes)
      const message = data.poe[0].lastBeacon
      const fastVerifyParams = await wbiInstance.computeFastVerifyParams(publicKey, proof, message)
      const signature = data.signature

      // post data request
      const tx1 = wbiInstance.postDataRequest(drBytes, web3.utils.toWei("1", "ether"), {
        from: accounts[0],
        value: web3.utils.toWei("1", "ether"),
      })
      const txHash1 = await waitForHash(tx1)
      const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
      const id1 = txReceipt1.logs[0].data

      // claim data request
      const tx2 = wbiInstance.claimDataRequests(
        [id1],
        proof,
        publicKey,
        fastVerifyParams[0],
        fastVerifyParams[1],
        signature, {
          from: accounts[1],
        })
      await waitForHash(tx2)

      var blockHeader2 = "0x" + sha.sha256("block header")
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
      const beacon = await wbiInstance.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))

      // report data request inclusion
      const tx3 = wbiInstance.reportDataRequestInclusion(id1, [data1], 0, blockHeader2, {
        from: accounts[0],
      })
      await waitForHash(tx3)

      // report result
      const tx4 = wbiInstance.reportResult(id1, [], 0, blockHeader2, resBytes, { from: accounts[1] })
      await waitForHash(tx4)

      // revert when reporting the same result
      await truffleAssert.reverts(
        wbiInstance.reportResult(id1, [], 1, blockHeader2, resBytes, { from: accounts[1] }),
        "Result already included"
      )
    })
    it("should revert because of trying to claim with an invalid signature",
      async () => {
        const drBytes = web3.utils.fromAscii("This is a DR7")

        // VRF params
        const publicKey = [data.publicKey.x, data.publicKey.y]
        const proofBytes = data.poe[0].proof
        const proof = await wbiInstance.decodeProof(proofBytes)
        const message = data.poe[0].lastBeacon
        const fastVerifyParams = await wbiInstance.computeFastVerifyParams(publicKey, proof, message)
        const signature = web3.utils.fromAscii("this is a fake sig")

        // post data request
        const tx1 = wbiInstance.postDataRequest(drBytes, web3.utils.toWei("1", "ether"), {
          from: accounts[0],
          value: web3.utils.toWei("1", "ether"),
        })
        const txHash1 = await waitForHash(tx1)
        const txReceipt1 = await web3.eth.getTransactionReceipt(txHash1)
        const id1 = txReceipt1.logs[0].data

        // revert when reporting the same result
        await truffleAssert.reverts(wbiInstance.claimDataRequests(
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
        const tx1 = wbiInstance.updateAbsActivity(block.number)
        await waitForHash(tx1)
      })
    it("should revert updating ABS activity with a future block",
      async () => {
        const block = await web3.eth.getBlock("latest")
        await truffleAssert.reverts(
          wbiInstance.updateAbsActivity(block.number + 100),
          "The block number provided has not been reached"
        )
      })
    it("should revert updating ABS activity with a past block",
      async () => {
        const block = await web3.eth.getBlock("latest")
        console.log(block.number)
        const newBlock = 49
        const tx1 = wbiInstance.updateAbsActivity(block.number)
        await waitForHash(tx1)
        await truffleAssert.reverts(
          wbiInstance.updateAbsActivity(newBlock),
          "The last block number updated was higher than the one provided"
        )
      })
  })
})

const waitForHash = txQ =>
  new Promise((resolve, reject) =>
    txQ.on("transactionHash", resolve).catch(reject)
  )
