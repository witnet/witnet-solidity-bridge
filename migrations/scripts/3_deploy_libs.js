const { merge } = require("lodash")

const realm = process.env.WITNET_EVM_REALM ? process.env.WITNET_EVM_REALM.toLowerCase() : "default"
const settings = require("../settings")
const artifactsName = merge(settings.artifacts.default, settings.artifacts[realm])

module.exports = async function (deployer, network) {
  let Witnet, CBOR
  const addresses = require("../addresses")[realm][network.split("-")[0]]

  // First: try to find CBOR artifact, and deploy it if not found in the addresses file:
  try {
    CBOR = artifacts.require(artifactsName.CBOR)
  } catch {
    console.log("\n   Skipped: 'CBOR' artifact not found.")
    return
  }
  if (!CBOR.isDeployed() || CBOR.address !== addresses.CBOR) {
    if (addresses) CBOR.address = addresses.CBOR
  }
  if (!CBOR.isDeployed() || isNullAddress(CBOR.address)) {
    await deployer.deploy(CBOR)
  } else {
    console.log(`\n   Skipped: 'CBOR' deployed at ${CBOR.address}.`)
  }
  // Second: try to find Witnet artifact, and deploy it if not found in the addesses file:
  try {
    Witnet = artifacts.require(artifactsName.Witnet)
  } catch {
    console.log("   Skipped: 'Witnet' artifact not found.\n")
    return
  }
  if (!Witnet.isDeployed() || Witnet.address !== addresses.Witnet) {
    if (addresses) Witnet.address = addresses.Witnet
  }
  if (!Witnet.isDeployed() || isNullAddress(Witnet.address)) {
    await deployer.link(CBOR, Witnet)
    await deployer.deploy(Witnet)
  } else {
    console.log(`   Skipped: 'Witnet' deployed at ${Witnet.address}.\n`)
  }
}

function isNullAddress (addr) {
  return !addr ||
    addr === "0x0000000000000000000000000000000000000000" ||
    !web3.utils.isAddress(addr)
}
