const { merge } = require("lodash")

const realm = process.env.WITNET_EVM_REALM ? process.env.WITNET_EVM_REALM.toLowerCase() : "default"
const settings = require("../settings")
const artifactsName = merge(settings.artifacts.default, settings.artifacts[realm])

module.exports = async function (deployer, network) {
  let WitnetParserLib, WitnetDecoderLib
  const addresses = require("../addresses")[realm][network.split("-")[0]]

  // First: try to find WitnetDecoderLib artifact, and deploy it if not found in the addresses file:
  try {
    WitnetDecoderLib = artifacts.require(artifactsName.WitnetDecoderLib)
  } catch {
    console.log("\n   Skipped: 'WitnetDecoderLib' artifact not found.")
    return
  }
  if (!WitnetDecoderLib.isDeployed() || WitnetDecoderLib.address !== addresses.WitnetDecoderLib) {
    if (addresses) WitnetDecoderLib.address = addresses.WitnetDecoderLib
  }
  if (!WitnetDecoderLib.isDeployed() || isNullAddress(WitnetDecoderLib.address)) {
    await deployer.deploy(WitnetDecoderLib)
  } else {
    console.log(`\n   Skipped: 'WitnetDecoderLib' deployed at ${WitnetDecoderLib.address}.`)
  }
  // Second: try to find WitnetParserLib artifact, and deploy it if not found in the addesses file:
  try {
    WitnetParserLib = artifacts.require(artifactsName.WitnetParserLib)
  } catch {
    console.log("   Skipped: 'WitnetParserLib' artifact not found.\n")
    return
  }
  if (!WitnetParserLib.isDeployed() || WitnetParserLib.address !== addresses.WitnetParserLib) {
    if (addresses) WitnetParserLib.address = addresses.WitnetParserLib
  }
  if (!WitnetParserLib.isDeployed() || isNullAddress(WitnetParserLib.address)) {
    await deployer.link(WitnetDecoderLib, WitnetParserLib)
    await deployer.deploy(WitnetParserLib)
  } else {
    console.log(`   Skipped: 'WitnetParserLib' deployed at ${WitnetParserLib.address}.\n`)
  }
}

function isNullAddress (addr) {
  return !addr ||
    addr === "0x0000000000000000000000000000000000000000" ||
    !web3.utils.isAddress(addr)
}
