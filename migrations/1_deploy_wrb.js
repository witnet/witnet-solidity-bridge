const addresses = require("./addresses.json")
const WitnetProxy = artifacts.require("WitnetProxy")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")

module.exports = async function (deployer, network, accounts) {
  network = network.split("-")[0]

  let deployWRB = true
  let upgradeProxy = true

  if (network in addresses) {
    if (addresses[network].WitnetProxy) {
      WitnetProxy.address = addresses[network].WitnetProxy
    }
    if (addresses[network].WitnetRequestBoard) {
      WitnetRequestBoard.address = addresses[network].WitnetRequestBoard
      if (!isNullAddress(WitnetRequestBoard.address)) {
        deployWRB = false
        if (WitnetProxy.isDeployed() && !isNullAddress(WitnetProxy.address)) {
          const proxy = await WitnetProxy.deployed()
          const currentWRB = await proxy.delegate.call()
          if (currentWRB.toLowerCase() !== WitnetRequestBoard.address.toLowerCase()) {
            console.log("Info: Witnet proxy delegate mismatch!")
            console.log()
            console.log(`  >> WitnetRequestBoard address in file: ${WitnetRequestBoard.address}`)
            console.log(`  >> WitnetProxy actual WRB instance:    ${currentWRB}`)
            console.log()
          } else {
            upgradeProxy = false
          }
        }
      }
    }
  }
  if (!WitnetProxy.isDeployed() || isNullAddress(WitnetProxy.address)) {
    console.log(`> Migrating new WitnetProxy instance into '${network}' network...`)
    await deployer.deploy(WitnetProxy)
    upgradeProxy = true
  }
  if (deployWRB) {
    console.log(`> Migrating new WitnetRequestBoard instance into ${network} network...`)
    await deployer.deploy(WitnetRequestBoard, true)
  }
  if (upgradeProxy) {
    const proxy = await WitnetProxy.deployed()
    const wrb = await WitnetRequestBoard.at(WitnetProxy.address)
    const oldAddr = await proxy.delegate.call()
    let oldCodehash
    let oldVersion
    if (!isNullAddress(oldAddr)) {
      oldCodehash = await wrb.codehash.call()
      oldVersion = await wrb.version.call()
    }
    console.log(`> Upgrading WitnetProxy instance at ${WitnetProxy.address}...`)
    console.log()
    await proxy.upgrade(
      WitnetRequestBoard.address,
      web3.eth.abi.encodeParameter(
        "address[]",
        [accounts[0]]
      )
    )
    if (isNullAddress(oldAddr)) {
      console.log(`  >> WRB owner addr:\t${await wrb.owner.call()}`)
      console.log(`  >> WRB address:\t${await proxy.delegate.call()}`)
      console.log(`  >> WRB codehash:\t${await wrb.codehash.call()}`)
      console.log(`  >> WRB version tag:\t${await wrb.version.call()}`)
    } else {
      console.log(`  >> WRB addresses:\t${oldAddr} => ${await proxy.delegate.call()}`)
      console.log(`  >> WRB codehashes:\t${oldCodehash} => ${await wrb.codehash.call()}`)
      console.log(`  >> WRB version tags:\t${oldVersion} => ${await wrb.version.call()}`)
    }    
    console.log(`  >> WRB is upgradable:\t${await wrb.isUpgradable.call()}`)
    console.log()
  }
}

function isNullAddress (addr) {
  return !addr ||
    addr === "" ||
    addr === "0x0000000000000000000000000000000000000000" ||
    !web3.utils.isAddress(addr)
}
