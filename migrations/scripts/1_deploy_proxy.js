const { merge } = require("lodash")

const realm = process.env.WITNET_EVM_REALM ? process.env.WITNET_EVM_REALM.toLowerCase() : "default"
const settings = require("../settings.witnet")
const artifactsName = merge(settings.artifacts.default, settings.artifacts[realm])

module.exports = async function (deployer, network) {
  let WitnetProxy
  const addresses = require("../addresses.witnet")[realm][network.split("-")[0]]

  try {
    WitnetProxy = artifacts.require(artifactsName.WitnetProxy)
  } catch {
    console.log("\n   Skipped: 'WitnetProxy' artifact not found.")
    return
  }
  if (!WitnetProxy.isDeployed() || WitnetProxy.address !== addresses.WitnetProxy) {
    if (addresses) WitnetProxy.address = addresses.WitnetProxy
  }
  if (!WitnetProxy.isDeployed() || isNullAddress(WitnetProxy.address)) {
    await deployer.deploy(WitnetProxy)
  } else {
    console.log(`\n   Skipped: 'WitnetProxy' deployed at ${WitnetProxy.address}.`)
  }
}

function isNullAddress (addr) {
  return !addr ||
    addr === "0x0000000000000000000000000000000000000000" ||
    !web3.utils.isAddress(addr)
}
