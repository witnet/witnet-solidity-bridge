const ethUtils = require('ethereumjs-util')
const fs = require('fs')
const utils = require('../utils/utils.js')

const SingletonFactory = artifacts.require("SingletonFactory")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")

module.exports = async function (deployer, network, accounts) {

  let addresses = require('./addresses.json')

  const factory = await SingletonFactory.deployed()
  const wrb = await WitnetRequestBoard.deployed()

  const singletons = require('./singletons.json') 
  const artifact = artifacts.require("WitnetRequestBoardProxy")
  const contract = artifact.contractName

  if (singletons.contracts[contract]) {

    let addresses = require('./addresses.json')

    const from = singletons.from
        ? singletons.from
        : deployer.networks[network].from
          ? deployer.networks[network].from
          : accounts[0]
      ;

    const salt = singletons.contracts[contract].salt
        ? '0x' + ethUtils.setLengthLeft(ethUtils.toBuffer(singletons.contracts[contract].salt), 32).toString('hex')
        : '0x0'
      ; 

    let bytecode = artifact.toJSON().bytecode
    if (singletons.contracts[contract].links) singletons.contracts[contract].links.forEach(
      // Join every dependent library address into the contract bytecode to be deployed:
      lib => {
        const lib_artifact = artifacts.require(lib)
        const lib_addr = lib_artifact.address.slice(2).toLowerCase()
        const lib_mark = `__${lib_artifact.contractName}${'_'.repeat(38 - lib_artifact.contractName.length)}`
        bytecode = bytecode.split(lib_mark).join(lib_addr)
      }
    )
    artifact.bytecode = bytecode

    var contract_addr = await factory.determineAddr.call(bytecode, salt)

    if ((await web3.eth.getCode(contract_addr)).length <= 3) {
      // Deploy contract instance, if not yet deployed on this `network`:
      traceHeader(`Singleton inception of contract '${contract}':`)

      const balance = await web3.eth.getBalance(from)
      const gas = singletons.contracts[contract].gas
          ? singletons.contracts[contract].gas
          : 10 ** 6
        ;

      // Compose initialization call: 'upgradeWitnetRequestBoard(wrb.address)'
      let initCall = '0x47b1e79b000000000000000000000000' + wrb.address.slice(2)

      const tx = await factory.deployAndInit(bytecode, initCall, salt, {from: from, gas: gas})
      utils.traceEvents(tx.logs)
      traceDeploymentTx(tx.receipt, web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString()))

    } else {
      traceHeader(`Singleton contract: '${contract}'`)
    }

    artifact.address = contract_addr
    const contract_codehash = web3.utils.soliditySha3(await web3.eth.getCode(artifact.address))
    if (!contract_codehash) {
      throw new Error(`Fatal: unable to deploy contract '${contract}' as singleton. Try providing more gas.`)
    }

    utils.logs.trace("  ", "> contract codehash:  ", web3.utils.soliditySha3(await web3.eth.getCode(artifact.address)))
    utils.logs.trace("  ", "> contract address:   ", artifact.address)
    utils.logs.trace("  ", "> current WRB address:", await (await artifact.deployed()).currentWitnetRequestBoard())
    if (singletons.contracts[contract].links && singletons.contracts[contract].links.length > 0) {
      utils.logs.trace("  ", "> linked libraries:\t", JSON.stringify(singletons.contracts[contract].links))
    }

    addresses["singletons"]["contracts"][contract] = contract_addr
  }

  utils.logs.trace()
  fs.writeFileSync("./migrations/addresses.json", JSON.stringify(addresses, null, 2))
}

function traceHeader(header) {
  utils.logs.trace("")
  utils.logs.trace("  ", header)
  utils.logs.trace("  ", `${'-'.repeat(header.length)}`)
}

function traceDeploymentTx(receipt, total_cost) {
  utils.logs.trace("  ", "> transaction hash:\t", receipt.transactionHash)
  utils.logs.trace("  ", "> block number:\t", receipt.blockNumber)
  utils.logs.trace("  ", "> gas used:\t\t", receipt.cumulativeGasUsed)
  if (total_cost) {
    utils.logs.trace("  ", "> total cost:\t", total_cost, "ETH")
  }
  utils.logs.trace()
}