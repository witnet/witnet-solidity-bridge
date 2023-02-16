const addresses = require("../witnet.addresses")
const thePackage = require("../../package")
const utils = require("../../scripts/utils")

const WitnetBytecodes = artifacts.require("WitnetBytecodes")
const WitnetRequestFactory = artifacts.require("WitnetProxy")
const WitnetRequestFactoryImplementation = artifacts.require("WitnetRequestFactory")

module.exports = async function (deployer, network, accounts) {
  if (network !== "test") {
    const isDryRun = network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
    const ecosystem = utils.getRealmNetworkFromArgs()[0]
    network = network.split("-")[0]

    if (!addresses[ecosystem]) addresses[ecosystem] = {}
    if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

    console.info()

    let proxy
    if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRequestFactory)) {
      await deployer.deploy(WitnetRequestFactory)
      proxy = await WitnetRequestFactory.deployed()
      addresses[ecosystem][network].WitnetRequestFactory = proxy.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      proxy = await WitnetRequestFactory.at(addresses[ecosystem][network].WitnetRequestFactory)
      console.info(`   Skipped: 'WitnetRequestFactory' deployed at ${proxy.address}`)
    }

    let factory
    if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRequestFactoryImplementation)) {
      await deployer.deploy(
        WitnetRequestFactoryImplementation,
        addresses[ecosystem][network].WitnetBytecodes || WitnetBytecodes.address,
        true,
        utils.fromAscii(thePackage.version)
      )
      factory = await WitnetRequestFactoryImplementation.deployed()
      addresses[ecosystem][network].WitnetRequestFactoryImplementation = factory.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      bytecodes = await WitnetRequestFactoryImplementation.at(addresses[ecosystem][network].WitnetRequestFactoryImplementation)
      console.info(`   Skipped: 'WitnetRequestFactoryImplementation' deployed at ${factory.address}`)
    }

    const implementation = await proxy.implementation()
    if (implementation.toLowerCase() !== factory.address.toLowerCase()) {
      console.info()
      console.info("   > WitnetRequestFactory proxy:", proxy.address)
      console.info("   > WitnetRequestFactory implementation:", implementation)
      console.info("   > WitnetRequestFactoryImplementation:", factory.address, `(v${await factory.version()})`)
      if (
        isDryRun
          || ["y", "yes"].includes((await utils.prompt("   > Upgrade the proxy ? [y/N] ")).toLowerCase().trim())
      ) {
        await proxy.upgradeTo(factory.address, "0x")
        console.info("   > Done.")
      } else {
        console.info("   > Not upgraded.")
      }
    }
  }
}