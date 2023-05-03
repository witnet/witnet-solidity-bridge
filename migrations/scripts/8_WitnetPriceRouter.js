const { merge } = require("lodash")

const addresses = require("../witnet.addresses")
const settings = require("../witnet.settings")
const utils = require("../../scripts/utils")
const version = `${
  require("../../package").version
}-${
  require("child_process").execSync("git rev-parse HEAD").toString().trim().substring(0, 7)
}`

const WitnetPriceRouter = artifacts.require("WitnetPriceRouter")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  console.info()
  if (!isDryRun && addresses[ecosystem][network].WitnetPriceRouter === undefined) {
    console.info(`\n   WitnetPriceRouter: Not to be deployed into '${network}'`)
    return
  }

  if (
    isDryRun
      || utils.isNullAddress(addresses[ecosystem][network]?.WitnetPriceRouter)
  ) {
    await deployer.deploy(
      WitnetPriceRouter,
      WitnetRequestBoard.address,
      false,
      utils.fromAscii(version),
      { from }
    )
    addresses[ecosystem][network].WitnetPriceRouter = WitnetPriceRouter.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    WitnetPriceRouter.address = addresses[ecosystem][network].WitnetPriceRouter
    console.info(`   Skipped: 'WitnetPriceRouter' deployed at ${WitnetPriceRouter.address}`)
  }
}
