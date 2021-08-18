const { merge } = require("lodash")

const realm = process.env.WITNET_EVM_REALM ? process.env.WITNET_EVM_REALM.toLowerCase() : "default"
const settings = require("../settings.witnet")
const artifactsName = merge(settings.artifacts.default, settings.artifacts[realm])

module.exports = async function (deployer, network, accounts) {
  let WitnetProxy, WitnetRequestBoard
  const addresses = require("../addresses.witnet")[realm][network.split("-")[0]]

  try {
    WitnetProxy = artifacts.require(artifactsName.WitnetProxy)
  } catch {
    console.log("\n   Skipped: 'WitnetProxy' artifact not found.")
    return
  }
  try {
    WitnetRequestBoard = artifacts.require(artifactsName.WitnetRequestBoard)
  } catch {
    console.log("\n   Skipped: 'WitnetRequestBoard' artifact not found.")
    return
  }

  let deployWRB = true
  let upgradeProxy = true
  if (addresses && addresses.WitnetRequestBoard) {
    WitnetRequestBoard.address = addresses.WitnetRequestBoard
    if (!isNullAddress(WitnetRequestBoard.address)) {
      // if there's a not null address established in 'addresses.json':
      // => no new WRB will be deployed
      deployWRB = false
      if (WitnetProxy.isDeployed() && !isNullAddress(WitnetProxy.address)) {
        // and if the proxy is already deployed...
        const proxy = await WitnetProxy.deployed()
        const currentWRB = await proxy.implementation.call()
        if (currentWRB.toLowerCase() !== WitnetRequestBoard.address.toLowerCase()) {
          // and proxy implementation differs from the WitnetRequestBoard established in 'addresses.json':
          console.log("\n   Info: Proxy's implementation mismatch!\n")
          console.log(`   >> WitnetRequestBoard address in file: ${WitnetRequestBoard.address}`)
          console.log(`   >> WitnetProxy actual WRB instance:    ${currentWRB}`)
          console.log()
          // => Proxy will be upgraded
        } else {
          // => Otherwise, Proxy won't be upgraded
          upgradeProxy = false
        }
      } else {
        console.error("\n   Fatal: 'WitnetProxy' not deployed?\n")
        process.exit(1)
      }
    }
  }
  if (deployWRB) {
    await deployer.deploy(
      WitnetRequestBoard,
      ...(
        // use realm-specific constructor parameters, if defined...
        settings.constructorParams[realm] && settings.constructorParams[realm].WitnetRequestBoard
          ? settings.constructorParams[realm].WitnetRequestBoard
          : settings.constructorParams.default.WitnetRequestBoard
      )
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
    console.log(`   Upgrading 'WitnetProxy' instance at ${WitnetProxy.address}:\n`)
    await proxy.upgradeTo(
      WitnetRequestBoard.address,
      web3.eth.abi.encodeParameter(
        "address[]",
        [accounts[0]]
      )
    )
    console.log(`   >> WRB owner address:  ${await wrb.owner.call()}`)
    if (isNullAddress(oldAddr)) {
      console.log(`   >> WRB address:        ${await proxy.implementation.call()}`)
      console.log(`   >> WRB proxiableUUID:  ${await wrb.proxiableUUID.call()}`)
      console.log(`   >> WRB codehash:       ${await wrb.codehash.call()}`)
      console.log(`   >> WRB version tag:    ${web3.utils.hexToString(await wrb.version.call())}`)
    } else {
      console.log(`   >> WRB addresses:      ${oldAddr} => ${await proxy.implementation.call()}`)
      console.log(`   >> WRB proxiableUUID:  ${await wrb.proxiableUUID.call()}`)
      console.log(`   >> WRB codehashes:     ${oldCodehash} => ${await wrb.codehash.call()}`)
      console.log(
        `   >> WRB version tags:   '${web3.utils.hexToString(oldVersion)}'`,
        `=> '${web3.utils.hexToString(await wrb.version.call())}'`
      )
    }
    console.log(`   >> WRB is upgradable:  ${await wrb.isUpgradable.call()}\n`)
  }
  if (!deployWRB && !upgradeProxy) {
    console.log(`\n   Skipped: 'WitnetRequestBoard' deployed at ${WitnetRequestBoard.address}.`)
  }
}

function isNullAddress (addr) {
  return !addr ||
    addr === "0x0000000000000000000000000000000000000000" ||
    !web3.utils.isAddress(addr)
}
