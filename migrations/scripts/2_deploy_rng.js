const { merge } = require("lodash")

const settings = require("../witnet.settings")
const utils = require("../../scripts/utils")
const { assert } = require("chai")

module.exports = async function (deployer, network, accounts) {
  const realm = network === "test"
    ? "default"
    : utils.getRealmNetworkFromArgs()[0]

  const addresses = require("../witnet.addresses")[realm][network = network.split("-")[0]]
  const artifactsName = merge(settings.artifacts.default, settings.artifacts[realm])

  if (addresses && addresses.WitnetRNG !== undefined) {
    assert(!utils.isNullAddress(addresses.WitnetRequestBoard), "\n  Skipped: no 'WitnetRequestBoard' was deployed.")

    /* Deploy WitnetRNG if not done yet */
    const WitnetRNG = artifacts.require(artifactsName.WitnetRNG)
    if (utils.isNullAddress(addresses.WitnetRNG)) {
      await deployer.deploy(
        WitnetRNG,
        addresses.WitnetRequestBoard
      )
    } else {
      console.log(`\n   Skipped: '${artifactsName.WitnetRNG}' deployed at ${addresses.WitnetRNG}.`)
    }
  }
}
