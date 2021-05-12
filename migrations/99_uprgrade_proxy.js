const utils = require('../utils/utils.js')
const WitnetRequestBoardProxy = artifacts.require("WitnetRequestBoardProxy")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")

module.exports = async function (deployer, network, accounts) {

  const WRB = await WitnetRequestBoard.deployed()
  const WRBProxy = await WitnetRequestBoardProxy.deployed()

  let current_wrb = await WRBProxy.currentWitnetRequestBoard.call()
  if (current_wrb !== WRB.address) {

    console.log(`> Upgrading 'WitnetRequestBoardProxy' singleton on '${network}' network...\n`)
    console.log("  ", "WRB owner address:", await WRB.owner.call())
    console.log("  ", "Old WRB address  :", current_wrb)
    let tx = await WRBProxy.upgradeWitnetRequestBoard(WitnetRequestBoard.address, {from: accounts[0]})
    console.log("  ", "New WRB address  :", await WRBProxy.currentWitnetRequestBoard.call())
    
  }

}