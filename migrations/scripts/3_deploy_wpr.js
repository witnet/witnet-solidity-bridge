const { merge } = require("lodash")

const settings = require("../witnet.settings")
const utils = require("../../scripts/utils")

module.exports = async function (deployer, network, accounts) {
  const realm = network === "test"
    ? "default"
    : utils.getRealmNetworkFromArgs()[0]

  const addresses = require("../witnet.addresses")[realm][network = network.split("-")[0]]
  const artifactsName = merge(settings.artifacts.default, settings.artifacts[realm])

  // Should the WitnetPriceRouter be deployed into this network:
  if (addresses && addresses.WitnetPriceRouter !== undefined) {
    let WitnetPriceRouter
    // First, find 'WitnetPriceRouter' implementation artifact
    try {
      WitnetPriceRouter = artifacts.require(artifactsName.WitnetPriceRouter)
    } catch {
      console.log(`\n   Fatal: '${artifactsName.WitnetPriceRouter}' artifact not found.`)
      process.exit(1)
    }
    if (isNullAddress(addresses.WitnetPriceRouter)) {
      // Deploy instance of 'WitnetPriceRouter', if not yet done so
      await deployer.deploy(WitnetPriceRouter)
    } else {
      console.log(`\n   Skipped: '${artifactsName.WitnetPriceRouter}' deployed at ${addresses.WitnetPriceRouter}.`)
    }
  } else {
    console.log(`\n   WitnetPriceRouter: Not to be deployed into '${network}'`)
  }
}

function isNullAddress (addr) {
  return !addr ||
        addr === "0x0000000000000000000000000000000000000000" ||
        !web3.utils.isAddress(addr)
}
