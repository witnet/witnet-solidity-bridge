const NewBlockRelay = artifacts.require("NewBlockRelay")
const sha = require("js-sha256")
const NewBRTestHelper = artifacts.require("NewBRTestHelper")
const truffleAssert = require("truffle-assertions")
contract("New Block Relay", accounts => {
  describe("New block relay test suite", () => {
    let contest
    beforeEach(async () => {
      await NewBlockRelay.new(1568559600, 90, {
        from: accounts[0],
      })
      contest = await NewBRTestHelper.new(1568559600, 90)
    })
    it("should propose and post a new block", async () => {
      // the blockhash we want to propose
      const vote = "0x" + sha.sha256("the vote to propose")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      const epoch = await contest.updateEpoch.call()
      // Propose the vote to the Block Relay
      const tx = contest.proposeBlock(vote, epoch - 1, drMerkleRoot, tallyMerkleRoot)
      await waitForHash(tx)
      // Wait unitl the next epoch to get the final result
      await contest.nextEpoch()
      // Call the Final Result
      await contest.finalresult()
      // Concatenation of the blockhash and the epoch-1 to check later if it's equal to the last beacon.blockHash
      const concatenated = web3.utils.hexToBytes(vote).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch - 1), 64
          )
        )
      )
      // Should be equal the last beacon to vote
      const beacon = await contest.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))
    })

    it("should post a new block when proposing in next epoch", async () => {
      // the blockhash we want to propose
      const vote1 = "0x" + sha.sha256("the vote to propose")
      const vote2 = "0x" + sha.sha256("second vote")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      const epoch = await contest.updateEpoch.call()
      // Propose the vote to the Block Relay
      const tx = contest.proposeBlock(vote1, epoch - 1, drMerkleRoot, tallyMerkleRoot)
      await waitForHash(tx)
      // Wait unitl the next epoch
      await contest.nextEpoch()
      // Propose another block in the new epoch and so post the previous one
      contest.proposeBlock(vote2, epoch, drMerkleRoot, tallyMerkleRoot)
      // Concatenation of the blockhash and the epoch -1 to check later if it's equal to the last beacon
      const concatenated = web3.utils.hexToBytes(vote1).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch - 1), 64
          )
        )
      )
      // Should be equal the last beacon
      const beacon = await contest.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))
    })

    it("should propose 3 blocks and post the winner", async () => {
      // The are to votes, vote1, voted once and vote 2 voted twice.
      // It should win vote2 and so be posted in the Block Relay
      const vote1 = "0x" + sha.sha256("first vote")
      const vote2 = "0x" + sha.sha256("second vote")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      const epoch = await contest.updateEpoch.call()
      // Propose vote1 to the Block Relay
      const tx1 = contest.proposeBlock(vote1, epoch - 1, drMerkleRoot, tallyMerkleRoot)
      await waitForHash(tx1)
      // Propose vote2 to the Block Relay
      contest.proposeBlock(vote2, epoch - 1, drMerkleRoot, tallyMerkleRoot)
      // Propose for the second time vote2
      contest.proposeBlock(vote2, epoch - 1, drMerkleRoot, tallyMerkleRoot)
      // Wait unitl the next epoch so to get the final result
      await contest.nextEpoch()
      // Now call the final result function to select the winner
      await contest.finalresult()
      // Concatenation of the blockhash and the epoch to check later if it's equal to the last beacon
      const concatenated = web3.utils.hexToBytes(vote2).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch - 1), 64
          )
        )
      )
      // Should be equal the last beacon to vote2, since is the most voted
      const beacon = await contest.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))
    })

    it("should detect there has been a tie and revert the post", async () => {
      // There are two blocks proposed once
      const vote1 = "0x" + sha.sha256("first vote")
      const vote2 = "0x" + sha.sha256("second vote")
      const drMerkleRoot = 1
      const drMerkleRoot2 = 2
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      const epoch = await contest.updateEpoch.call()
      // Propose block1 to the Block Relay
      const tx1 = contest.proposeBlock(vote1, epoch - 1, drMerkleRoot, tallyMerkleRoot)
      await waitForHash(tx1)
      // Propose block2 to the Block Relay
      const tx2 = contest.proposeBlock(vote2, epoch - 1, drMerkleRoot2, tallyMerkleRoot)
      await waitForHash(tx2)
      // Let's wait unitl the next epoch so we can get the final result
      await contest.nextEpoch()
      // It reverts the finalResult() since it detects there is been a tie
      await truffleAssert.reverts(contest.finalresult(), "There has been a tie")
    })

    it("should revert because the block proposed is not for a valid epoch", async () => {
      const vote = "0x" + sha.sha256("vote proposed")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      const epoch = await contest.updateEpoch.call()
      await truffleAssert.reverts(contest.proposeBlock(vote, epoch, drMerkleRoot, tallyMerkleRoot),
        "Proposing a block for a non valid epoch")
    })

    it("should set the candidates array to 0 after posting a block", async () => {
      // the blockhash we want to propose
      const vote = "0x" + sha.sha256("the vote to propose")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      let setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      let epoch = await contest.updateEpoch.call()
      // Propose the vote to the Block Relay
      const tx = contest.proposeBlock(vote, epoch - 1, drMerkleRoot, tallyMerkleRoot)
      await waitForHash(tx)
      // Fix the timestamp to be one epoch later
      setEpoch = contest.setEpoch(89160)
      await waitForHash(setEpoch)
      epoch = await contest.updateEpoch.call()
      // Call the final result so it posts the block header to the block relay and sets the candidate array to 0
      await contest.finalresult()
      // The candidates array
      const candidate = await contest.getCandidates.call()
      // Assert the candidates array is equal to 0
      assert.equal(0, candidate)
    })
  })
})

const waitForHash = txQ =>
  new Promise((resolve, reject) =>
    txQ.on("transactionHash", resolve).catch(reject)
  )
