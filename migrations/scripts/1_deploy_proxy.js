const realm = process.env.WITNET_EVM_REALM || "default"
const addresses = require("../addresses")[realm]
const settings = require("../settings")

let WitnetProxy

module.exports = async function (deployer, network, accounts) {
  try {
    WitnetProxy = artifacts.require(settings.artifacts[realm].WitnetProxy || settings.artifacts.default.WitnetProxy)
  } catch {
    console.log("Skipped: 'WitnetProxy' artifact not found.")
    return
  }

  network = network.split("-")[0]
  if (network in addresses) {
    WitnetProxy.address = addresses[network].WitnetProxy
  }
  if (!WitnetProxy.isDeployed() || isNullAddress(WitnetProxy.address)) {
    console.log(`> Migrating new 'WitnetProxy' instance into "${realm}:${network}"...`)
    await deployer.deploy(WitnetProxy)
  } else {
    console.log()
    console.log(`> Skipped: 'WitnetProxy' deployed at ${WitnetProxy.address}.`)
  }
}

function isNullAddress (addr) {
  return !addr ||
    addr === "" ||
    addr === "0x0000000000000000000000000000000000000000" ||
    !web3.utils.isAddress(addr)
}
