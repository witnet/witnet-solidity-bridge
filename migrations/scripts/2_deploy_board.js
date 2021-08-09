const realm = process.env.WITNET_EVM_REALM || "default"
const addresses = require("../addresses")[realm]
const settings = require("../settings")

let WitnetProxy, WitnetRequestBoard

module.exports = async function (deployer, network, accounts) {
  try {
    WitnetProxy = artifacts.require(settings.artifacts[realm].WitnetProxy || settings.artifacts.default.WitnetProxy)
    WitnetRequestBoard = artifacts.require(
      settings.artifacts[realm].WitnetRequestBoard || settings.artifacts.default.WitnetRequestBoard
    )
  } catch {
    console.log("Skipped: 'WitnetRequestBoard' artifact not found.")
    return
  }

  let deployWRB = true
  let upgradeProxy = true

  network = network.split("-")[0]
  if (network in addresses) {
    if (addresses[network].WitnetRequestBoard) {
      WitnetRequestBoard.address = addresses[network].WitnetRequestBoard
      if (!isNullAddress(WitnetRequestBoard.address)) {
        deployWRB = false
        if (WitnetProxy.isDeployed() && !isNullAddress(WitnetProxy.address)) {
          const proxy = await WitnetProxy.deployed()
          const currentWRB = await proxy.implementation.call()
          if (currentWRB.toLowerCase() !== WitnetRequestBoard.address.toLowerCase()) {
            console.log("Info: Witnet proxy implementation mismatch!")
            console.log()
            console.log(`  >> WitnetRequestBoard address in file: ${WitnetRequestBoard.address}`)
            console.log(`  >> WitnetProxy actual WRB instance:    ${currentWRB}`)
            console.log()
          } else {
            upgradeProxy = false
          }
        } else {
          console.error("Fatal: WitnetProxy not deployed?")
          process.exit(1)
        }
      }
    }
  }

  if (deployWRB) {
    console.log(`> Migrating new 'WitnetRequestBoard' instance into "${realm}:${network}"...`)
    await deployer.deploy(
      WitnetRequestBoard,
      ...settings.constructorParams[realm].WitnetRequestBoard ||
      settings.constructorParams.default.WitnetRequestBoard
    )
  }

  if (upgradeProxy) {
    const proxy = await WitnetProxy.deployed()
    const wrb = await WitnetRequestBoard.at(WitnetProxy.address)
    const oldAddr = await proxy.implementation.call()
    let oldCodehash
    let oldVersion
    if (!isNullAddress(oldAddr)) {
      oldCodehash = await wrb.codehash.call()
      oldVersion = await wrb.version.call()
    }
    console.log(`> Upgrading 'WitnetProxy' instance at ${WitnetProxy.address}...`)
    console.log()
    await proxy.upgradeTo(
      WitnetRequestBoard.address,
      web3.eth.abi.encodeParameter(
        "address[]",
        [accounts[0]]
      )
    )
    console.log(`  >> WRB owner address:\t${await wrb.owner.call()}`)
    if (isNullAddress(oldAddr)) {
      console.log(`  >> WRB address:\t${await proxy.implementation.call()}`)
      console.log(`  >> WRB codehash:\t${await wrb.codehash.call()}`)
      console.log(`  >> WRB version tag:\t${web3.utils.hexToString(await wrb.version.call())}`)
    } else {
      console.log(`  >> WRB addresses:\t${oldAddr} => ${await proxy.implementation.call()}`)
      console.log(`  >> WRB codehashes:\t${oldCodehash} => ${await wrb.codehash.call()}`)
      console.log(
        `  >> WRB version tags:\t'${web3.utils.hexToString(oldVersion)}'`,
        `=> '${web3.utils.hexToString(await wrb.version.call())}'`
      )
    }
    console.log(`  >> WRB is upgradable:\t${await wrb.isUpgradable.call()}`)
    console.log(`  >> WRB proxiableUUID:\t${await wrb.proxiableUUID.call()}`)
    console.log()
  }

  if (!deployWRB && !upgradeProxy) {
    console.log("\n> Skipped: no 'WitnetRequestBoard' to upgrade.")
  }
}

function isNullAddress (addr) {
  return !addr ||
    addr === "0x0000000000000000000000000000000000000000" ||
    !web3.utils.isAddress(addr)
}
