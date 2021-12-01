const { merge } = require("lodash")

const settings = require("../witnet.settings")
const utils = require("../../scripts/utils")

module.exports = async function (deployer, network, accounts) {
  const realm = network === "test"
    ? "default"
    : utils.getRealmNetworkFromArgs()[0]

  const addresses = require("../witnet.addresses")[realm][network = network.split("-")[0]]
  const artifactsName = merge(settings.artifacts.default, settings.artifacts[realm])

  // Should the WitnetPriceRegistry be deployed into this network:
  if (addresses && addresses.WitnetPriceRegistry !== undefined) {
    let WitnetPriceRegistry
    // First, find 'WitnetPriceRegistry' implementation artifact
    try {
      WitnetPriceRegistry = artifacts.require(artifactsName.WitnetPriceRegistry)
    } catch {
      console.log(`\n   Fatal: '${artifactsName.WitnetPriceRegistry}' artifact not found.`)
      process.exit(1)
    }
    if (isNullAddress(addresses.WitnetPriceRegistry)) {
      // Deploy instance of 'WitnetPriceRegistry', if not yet done so
      await deployer.deploy(WitnetPriceRegistry)
    } else {
      console.log(`\n   Skipped: '${artifactsName.WitnetPriceRegistry}' deployed at ${addresses.WitnetPriceRegistry}.`)
    }
  } else {
    console.log(`\n   Not to be deployed into '${network}'`)
  }
}

function isNullAddress (addr) {
  return !addr ||
        addr === "0x0000000000000000000000000000000000000000" ||
        !web3.utils.isAddress(addr)
}
