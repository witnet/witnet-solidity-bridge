const NewBlockRelay = artifacts.require("NewBlockRelay")
const sha = require("js-sha256")
const NewBRTestHelper = artifacts.require("NewBRTestHelper")
const truffleAssert = require("truffle-assertions")
contract("New Block Relay", accounts => {
  describe("New block relay test suite", () => {
    let contest
    beforeEach(async () => {
      await NewBlockRelay.new(1568559600, 90, 0, {
        from: accounts[0],
      })
      contest = await NewBRTestHelper.new(1568559600, 90, 0)
    })
    it("should propose and post a new block", async () => {
      // The blockhash we want to propose
      const blockHash = "0x" + sha.sha256("the vote to propose")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      let epoch = await contest.updateEpoch.call()
      contest.setPreviousEpochFinalized()
      // Update the ABS to be included
      await contest.pushActivity(1)
      // Set the ABS to just one member
      await contest.setAbsIdentitiesNumber(1)
      // Propose the vote to the Block Relay
      const tx = contest.proposeBlock(blockHash, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx)
      // Get the vote proposed as the concatenation of the elemetns of the proposeBlock
      const Vote = await contest.getVote.call(blockHash, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      // Wait unitl the next epoch to get the final result
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose another block in the next epoch so the previous one is finalized
      await contest.proposeBlock(0, epoch - 1, 0, 0, Vote)
      // Concatenation of the blockhash and the epoch-1 to check later if it's equal to the last beacon
      const concatenated = web3.utils.hexToBytes(blockHash).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch - 2), 64
          )
        )
      )
      // Should be equal the last beacon to vote
      const beacon = await contest.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))
    })

    it("should propose 3 blocks for the same epoch and post the winner", async () => {
      // The are to votes: blockHash1, voted once and blockHash2 voted twice.
      // It should win blockHash2 and so be posted in the Block Relay
      const blockHash1 = "0x" + sha.sha256("first vote")
      const blockHash2 = "0x" + sha.sha256("second vote")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      const epoch = await contest.updateEpoch.call()
      // Update the ABS to be included
      await contest.pushActivity(1)
      // Propose vote1 to the Block Relay
      const tx1 = contest.proposeBlock(blockHash1, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx1)
      // Propose vote2 to the Block Relay
      contest.proposeBlock(blockHash2, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      // Propose for the second time vote2
      contest.proposeBlock(blockHash2, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      const Vote2 = await contest.getVote.call(blockHash2, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      // Wait unitl the next epoch so to get the final result
      await contest.nextEpoch()
      // Propose another block in the next epoch so the previous one is finalized
      await contest.proposeBlock(0, epoch, 0, 0, Vote2)
      // Concatenation of the blockhash and the epoch to check later if it's equal to the last beacon
      const concatenated = web3.utils.hexToBytes(blockHash2).concat(
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

    it("should post a new block when getting consensus", async () => {
      // the blockhash we want to propose
      const blockHash1 = "0x" + sha.sha256("the vote to propose")
      const blockHash2 = "0x" + sha.sha256("second vote")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      const epoch = await contest.updateEpoch.call()
      // Update the ABS to be included
      await contest.pushActivity(1)
      // Set the number of members of the ABS to 3
      await contest.setAbsIdentitiesNumber(3)
      // Propose the vote 3 times to the Block Relay
      const tx = contest.proposeBlock(blockHash1, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx)
      const tx2 = contest.proposeBlock(blockHash1, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx2)
      const tx3 = contest.proposeBlock(blockHash1, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx3)
      // Get the vote proposed as the concatenation of the elemetns of the proposeBlock
      const Vote = await contest.getVote.call(blockHash1, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      // Wait unitl the next epoch
      await contest.nextEpoch()
      // Propose another block in the new epoch and so post the previous one
      contest.proposeBlock(blockHash2, epoch, drMerkleRoot, tallyMerkleRoot, Vote)
      // Concatenation of the blockhash and the epoch -1 to check later if it's equal to the last beacon
      const concatenated = web3.utils.hexToBytes(blockHash1).concat(
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

    it("should set the previos block to pending when not achieved 2/3 of the ABS", async () => {
      // the blockhash we want to propose
      const blockHash = "0x" + sha.sha256("the vote to propose")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      const epoch = await contest.updateEpoch.call()
      // Update the ABS to be included
      await contest.pushActivity(1)
      // Set the abs to 3 identities
      await contest.setAbsIdentitiesNumber(3)
      // Propose the vote to the Block Relay
      const tx = contest.proposeBlock(blockHash, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx)
      // Wait unitl the next epoch to get the final result
      await contest.nextEpoch()
      // Propose another block in the next epoch so the previous one is finalized
      await contest.proposeBlock(0, epoch, 0, 0, 0)
      // Check the status of epoch -2
      const epochStatus = await contest.checkStatusPending.call()
      assert.equal(epochStatus, true)
    })

    it("should revert because the block proposed is not for a valid epoch", async () => {
      const vote = "0x" + sha.sha256("vote proposed")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      const epoch = await contest.updateEpoch.call()
      // Update the ABS to be included
      await contest.pushActivity(1)
      // Should revert because proposing for the current epoch
      await truffleAssert.reverts(contest.proposeBlock(vote, epoch, drMerkleRoot, tallyMerkleRoot, 0),
        "Proposing a block for a non valid epoch")
    })

    it("should revert because not in the ABS", async () => {
      const vote = "0x" + sha.sha256("vote proposed")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      const epoch = await contest.updateEpoch.call()
      // should revert beacause not a memeber of the ABS
      await truffleAssert.reverts(contest.proposeBlock(vote, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0),
        "Not a member of the abs")
    })

    it("should check a vote that is a candidates is deleted when posted", async () => {
      // the blockhash we want to propose
      const blockHash = "0x" + sha.sha256("the vote to propose")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      let setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      let epoch = await contest.updateEpoch.call()
      // Update the ABS to be included
      await contest.pushActivity(1)
      // Propose the vote to the Block Relay
      const tx = contest.proposeBlock(blockHash, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx)
      // Fix the timestamp to be one epoch later
      setEpoch = contest.setEpoch(89160)
      await waitForHash(setEpoch)
      epoch = await contest.updateEpoch.call()
      // Propose another block in the next epoch so the previous one is finalized
      await contest.proposeBlock(0, epoch - 1, 0, 0, 0)
      // The candidates array
      const candidate = await contest.getCandidatesLength.call()
      // Assert there is just one candidate since the first is been canceled when posted
      assert.equal(1, candidate)
    })

    it("should finalize a block and the previous epochs when Pending", async () => {
      // The idea is that after two epoch with no consesus, when in epoch n the consensus is achived then
      // epochs n-1 and n-2 are finalized as well
      const blockHash0 = "0x" + sha.sha256("null vote")
      const blockHash1 = "0x" + sha.sha256("first vote")
      const blockHash2 = "0x" + sha.sha256("second vote")
      const blockHash3 = "0x" + sha.sha256("third vote")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      let epoch = await contest.updateEpoch.call()
      // Update the ABS to be included
      await contest.pushActivity(1)
      // Set the ABS to 3 members
      await contest.setAbsIdentitiesNumber(3)
      // Propose blockHash0 to he Block Relay 3 times
      const tx = contest.proposeBlock(blockHash0, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx)
      contest.proposeBlock(blockHash0, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      contest.proposeBlock(blockHash0, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      const Vote = await contest.getVote.call(blockHash0, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose blockHash1 to the Block Relay
      const tx2 = contest.proposeBlock(blockHash1, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote)
      await waitForHash(tx2)
      const Vote1 = await contest.getVote.call(blockHash1, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote)
      // Wait for next epoch
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose blockHash2 to the Block Relay
      const tx3 = contest.proposeBlock(blockHash2, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote1)
      await waitForHash(tx3)
      const Vote2 = await contest.getVote.call(blockHash2, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote1)
      // Wait for next epoch
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose 3 times blockHash3 to the Block Relay
      contest.proposeBlock(blockHash3, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote2)
      contest.proposeBlock(blockHash3, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote2)
      contest.proposeBlock(blockHash3, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote2)
      const Vote3 = await contest.getVote.call(blockHash3, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote2)
      // Wait for next epoch
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose a random vote just to finalize previous epochs
      await contest.proposeBlock(blockHash2, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote3)
      // Now we want to check that
      const epochStatus = await contest.checkStatusFinalized.call()
      assert.equal(epochStatus, true)
    })

    it("should confirm a vote is been finalized", async () => {
      // The idea is that after two epoch with no consesus, when in epoch n the consensus
      // is achived epochs n-1 and n-2 are finalized as well
      const blockHash0 = "0x" + sha.sha256("null vote")
      const blockHash1 = "0x" + sha.sha256("first vote")
      const blockHash2 = "0x" + sha.sha256("second vote")
      const blockHash3 = "0x" + sha.sha256("third vote")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      let epoch = await contest.updateEpoch.call()
      // Update the ABS to be included
      await contest.pushActivity(1)
      // Set the ABS to 3 members
      await contest.setAbsIdentitiesNumber(3)
      // Propose blockHash0 3 times to the Block Relay
      const tx = contest.proposeBlock(blockHash0, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx)
      const tx1 = contest.proposeBlock(blockHash0, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx1)
      const tx2 = contest.proposeBlock(blockHash0, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx2)
      const Vote1 = await contest.getVote.call(blockHash0, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose blockHash1 to the Block Relay
      const tx3 = contest.proposeBlock(blockHash1, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote1)
      await waitForHash(tx3)
      const Vote2 = await contest.getVote.call(blockHash1, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote1)
      // Wait for next epoch
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose blockHash2 to the Block Relay
      const tx7 = contest.proposeBlock(blockHash2, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote2)
      await waitForHash(tx7)
      const Vote3 = await contest.getVote.call(blockHash2, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote2)
      // Wait for next epoch
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose 3 times blockHash3 to the Block Relay
      const tx4 = contest.proposeBlock(blockHash3, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote3)
      await waitForHash(tx4)
      const tx5 = contest.proposeBlock(blockHash3, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote3)
      await waitForHash(tx5)
      const tx6 = contest.proposeBlock(blockHash3, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote3)
      await waitForHash(tx6)
      const Vote4 = await contest.getVote.call(blockHash3, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote3)
      // Wait for next epoch
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose a random vote just to finalize previous epochs
      await contest.proposeBlock(blockHash2, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote4)
      // Check the blockHash for epoch 89161 is the right one
      let blockHash = await contest.getBlockHash.call(89161)
      blockHash = "0x" + blockHash.toString(16)
      const concatenated = web3.utils.hexToBytes(blockHash).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch - 2), 64
          )
        )
      )
      // Should be equal the last beacon to vote
      const beacon = await contest.getLastBeacon.call()
      assert.equal(beacon, web3.utils.bytesToHex(concatenated))
    })

    it("should confirm that currentEpoch - 3 is been posted", async () => {
      // The idea is that after two epoch with no consesus, when in epoch n the
      // consensus is achived then previpus epochs that were pending are finalized as well
      const blockHash0 = "0x" + sha.sha256("null vote")
      const blockHash1 = "0x" + sha.sha256("first vote")
      const blockHash2 = "0x" + sha.sha256("second vote")
      const blockHash3 = "0x" + sha.sha256("third vote")
      const drMerkleRoot = 1
      const tallyMerkleRoot = 1
      // Fix the timestamp in witnet to be 89159
      const setEpoch = contest.setEpoch(89159)
      await waitForHash(setEpoch)
      let epoch = await contest.updateEpoch.call()
      // Update the ABS to be included
      await contest.pushActivity(1)
      // Set the ABS to 3 members
      await contest.setAbsIdentitiesNumber(3)
      // Propose blockHash0 3 times to the Block Relay
      const tx = contest.proposeBlock(blockHash0, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx)
      const tx1 = contest.proposeBlock(blockHash0, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx1)
      const tx2 = contest.proposeBlock(blockHash0, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      await waitForHash(tx2)
      const Vote1 = await contest.getVote.call(blockHash0, epoch - 1, drMerkleRoot, tallyMerkleRoot, 0)
      // Wait for the next epoch
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose blockHash1 to the Block Relay
      const tx3 = contest.proposeBlock(blockHash1, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote1)
      await waitForHash(tx3)
      const Vote2 = await contest.getVote.call(blockHash1, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote1)
      // Wait for next epoch
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose blockHash2 to the BlockRelay
      const tx7 = contest.proposeBlock(blockHash2, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote2)
      await waitForHash(tx7)
      const Vote3 = await contest.getVote.call(blockHash2, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote2)
      // Wait for next epoch
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose 3 times blockHash3 to the Block Relay
      const tx4 = contest.proposeBlock(blockHash3, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote3)
      await waitForHash(tx4)
      const tx5 = contest.proposeBlock(blockHash3, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote3)
      await waitForHash(tx5)
      const tx6 = contest.proposeBlock(blockHash3, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote3)
      await waitForHash(tx6)
      const Vote4 = await contest.getVote.call(blockHash3, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote3)
      // Wait for next epoch
      await contest.nextEpoch()
      epoch = await contest.updateEpoch.call()
      // Propose a random vote just to finalize previous epochs
      await contest.proposeBlock(blockHash2, epoch - 1, drMerkleRoot, tallyMerkleRoot, Vote4)
      // Get the blockHash finalized for the epoch 89160
      let blockHash = await contest.getBlockHash.call(89160)
      blockHash = "0x" + blockHash.toString(16)
      const concatenated = web3.utils.hexToBytes(blockHash).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch - 3), 64
          )
        )
      )
      const concatenated2 = web3.utils.hexToBytes(blockHash2).concat(
        web3.utils.hexToBytes(
          web3.utils.padLeft(
            web3.utils.toHex(epoch - 3), 64
          )
        )
      )
      // The block hash in epoch 89160 should be equal to blockHash2
      assert.equal(web3.utils.bytesToHex(concatenated), web3.utils.bytesToHex(concatenated2))
    })
  })
})
const waitForHash = txQ =>
  new Promise((resolve, reject) =>
    txQ.on("transactionHash", resolve).catch(reject)
  )
