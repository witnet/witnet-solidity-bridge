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

    assert(!utils.isNullAddress(addresses.WitnetRequestBoard), "\n  Skipped: no 'WitnetRequestBoard' was deployed.")

  /* Deploy WitnetRNG if not done yet */
    if (utils.isNullAddress(addresses.WitnetRNG)) {
  }
}


