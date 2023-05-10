const fs = require("fs")

const addresses = require("../witnet.addresses")
const utils = require("../../scripts/utils")

const Create2Factory = artifacts.require("Create2Factory")

module.exports = async function (deployer, network, [, from,,,,, master]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  let factory
  if (utils.isNullAddress(addresses[ecosystem][network]?.Create2Factory)) {
    await deployer.deploy(Create2Factory, { from: master })
    factory = await Create2Factory.deployed()
    addresses[ecosystem][network].Create2Factory = factory.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    factory = await Create2Factory.at(addresses[ecosystem][network].Create2Factory)
    Create2Factory.address = factory.address
    utils.traceHeader("Skipping 'Create2Factory'")
    console.info("   > Contract address:", factory.address)
    console.info()
  }

  // Settle WitnetProxy bytecode and source code as to guarantee
  // salted addresses remain as expected no matter if the solc version
  // is changed in migrations/witnet.settings.js
  utils.traceHeader("Defrosting 'WitnetProxy' artifact")
  fs.writeFileSync(
    `build/${ecosystem}/contracts/WitnetProxy.json`,
    fs.readFileSync("migrations/abis/WitnetProxy.json"),
    { encoding: "utf8", flag: "w" }
  )
  const WitnetProxy = artifacts.require("WitnetProxy")
  const metadata = JSON.parse(WitnetProxy.metadata)
  console.info("  ", "> compiler:          ", metadata.compiler.version)
  console.info("  ", "> compilation target:", metadata.settings.compilationTarget)
  console.info("  ", "> evmVersion:        ", metadata.settings.evmVersion)
  console.info("  ", "> optimizer:         ", JSON.stringify(metadata.settings.optimizer))

  if (addresses[ecosystem][network]?.WitnetProxy === "") {
    await deployer.deploy(WitnetProxy, { from })
    addresses[ecosystem][network].WitnetProxy = WitnetProxy.address
  } else {
    if (addresses[ecosystem][network]?.WitnetProxy) {
      WitnetProxy.address = addresses[ecosystem][network]?.WitnetProxy
    }
  }
  if (!isDryRun) {
    utils.saveAddresses(addresses)
  }
}
