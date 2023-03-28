const cbor = require("cbor")
const exec = require("child_process").execSync
const { merge } = require("lodash")

const addresses = require("../../../witnet.addresses")
const utils = require("../../../../scripts/utils")

const WitnetRandomness = artifacts.require("WitnetRandomness")
const WitnetRequestRandomness = artifacts.require("WitnetRequestRandomness")

module.exports = async function (deployer, network, [, from]) {

  const [realm, chain] = utils.getRealmNetworkFromString(network.split("-")[0])

  let randomizer = await WitnetRandomness.at(addresses[realm][chain].WitnetRandomness)
  let request = await WitnetRequestRandomness.at(await randomizer.witnetRandomnessRequest.call())
  let owner = await request.owner.call()
  let radonSLA = { ...(await request.witnessingParams.call()) }

  console.log("> WitnetRandomness address:", randomizer.address)
  console.log("> WitnetRequestRandomness address:", request.address)
  console.log("> WitnetRequestRadnomness owner:", owner)
  console.log("> Current commit/reval fee:", radonSLA.witnessingUnitaryFee)
  console.log("> Current number of witnesses:", radonSLA.numWitnesses)
  console.log("> Current witnessing reward:", radonSLA.witnessingReward)
  console.log("> Current witnessing collateral:", radonSLA.witnessingCollateral)
  console.log("> Current witnessing consensus:", radonSLA.minWitnessingConsensus, "%")
  
  let tbs = [ false, false, false, false, false ]
  process.argv.map((argv, index, args) => {
    if (argv === '--reward') {
      if (args[index + 1] !== radonSLA.witnessingReward) {
        radonSLA.witnessingReward = args[index + 1]
        tbs[3] = true
      }
    } else if (argv === '--collateral') {
      if (args[index + 1] !== radonSLA.witnessingCollateral) {
        radonSLA.witnessingCollateral = args[index + 1]
        tbs[2] = true
      }
    } else if (argv === '--witnesses') {
      if (args[index + 1] !== radonSLA.numWitnesses) {
        radonSLA.numWitnesses = args[index + 1]
        tbs[0] = true
      }
    } else if (argv === '--quorum') {
      if (args[index + 1] !== radonSLA.minWitnessingConsensus) {
        radonSLA.minWitnessingConsensus = args [index + 1]
        tbs[1] = true
      }
    } else if (argv === '--unitary-fee') {
      if (args[index + 1] !== radonSLA.witnessingUnitaryFee) {
        radonSLA.witnessingUnitaryFee = args [index + 1]
        tbs[4] = true
      }
    }
  })
  if (tbs[2]) {
    console.log(`\n=> Setting witnessing collateral to ${radonSLA.witnessingCollateral}...`)
    try {
      let tx = await request.setWitnessingCollateral(
        radonSLA.witnessingCollateral, 
        { from: owner}
      )
      console.log("   > transaction hash:", tx.receipt.transactionHash)
    } catch (ex) {
      console.log("   > Failed:", ex)
    }
  }
  if (tbs[3] || tbs[4]) {
    console.log(`\n=> Setting witnessing reward to ${radonSLA.witnessingReward}...`)
    console.log(`=> Setting commit/reveal fee to ${radonSLA.witnessingUnitaryFee}...`)
    try {
      let tx = await request.setWitnessingFees(
        radonSLA.witnessingReward, 
        radonSLA.witnessingUnitaryFee, 
        { from: owner}  
      )
      console.log("   > transaction hash:", tx.receipt.transactionHash)
    } catch (ex) {
      console.log("   > Failed:", ex)
    }
  }
  if (tbs[0] || tbs[1]) {
    console.log(`\n=> Setting number of witnesses to ${radonSLA.numWitnesses}...`)
    console.log(`=> Setting witnessing consensus to ${radonSLA.minWitnessingConsensus}%...`)
    try {
      let tx = await request.setWitnessingQuorum(
        radonSLA.numWitnesses, 
        radonSLA.minWitnessingConsensus, 
        { from: owner}
      )
      console.log("   > transaction hash:", tx.receipt.transactionHash)
    } catch (ex) {
      console.log("   > Failed:", ex)
    }
  }
  console.log()
}