const fs = require("fs")

const addresses = require("../witnet.addresses")
const thePackage = require("../../package")
const utils = require("../../scripts/utils")

const WitnetBytecodesProxy = artifacts.require("WitnetProxy")
const WitnetBytecodesImplementation = artifacts.require("WitnetBytecodes")
const WitnetEncodingLib = artifacts.require("WitnetEncodingLib")

module.exports = async function (deployer, network, accounts) {
  if (network !== "test") {
    const isDryRun = network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
    const ecosystem = utils.getRealmNetworkFromArgs()[0]
    network = network.split("-")[0]

    if (!addresses[ecosystem]) addresses[ecosystem] = {}
    if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

    console.info()

    let proxy
    if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetBytecodes)) {
      await deployer.deploy(WitnetBytecodesProxy)
      proxy = await WitnetBytecodesProxy.deployed()
      addresses[ecosystem][network].WitnetBytecodes = proxy.address
      if (!isDryRun) {
        saveAddresses(addresses)
      }
    } else {
      proxy = await WitnetBytecodesProxy.at(addresses[ecosystem][network].WitnetBytecodes)
      console.info(`   Skipped: 'WitnetBytecodesProxy' deployed at ${proxy.address}`)
    }

    let bytecodes
    if (
      utils.isNullAddress(addresses[ecosystem][network]?.WitnetBytecodesImplementation) ||
        utils.isNullAddress(addresses[ecosystem][network]?.WitnetEncodingLib)
    ) {
      if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetEncodingLib)) {
        await deployer.deploy(WitnetEncodingLib)
        addresses[ecosystem][network].WitnetEncodingLib = WitnetEncodingLib.address
        if (!isDryRun) {
          saveAddresses(addresses)
        }
      } else {
        WitnetEncodingLib.address = addresses[ecosystem][network].WitnetEncodingLib
        await WitnetEncodingLib.deployed()
        console.info(`   Skipped: 'WitnetEncodingLib' deployed at ${addresses[ecosystem][network].WitnetEncodingLib}`)
      }
      await deployer.link(
        WitnetEncodingLib,
        [WitnetBytecodesImplementation]
      )
      await deployer.deploy(
        WitnetBytecodesImplementation,
        true,
        utils.fromAscii(thePackage.version)
      )
      bytecodes = await WitnetBytecodesImplementation.deployed()
      addresses[ecosystem][network].WitnetBytecodesImplementation = bytecodes.address
      if (!isDryRun) {
        saveAddresses(addresses)
      }
    } else {
      bytecodes = await WitnetBytecodesImplementation.at(addresses[ecosystem][network].WitnetBytecodesImplementation)
      console.info(`   Skipped: 'WitnetBytecodesImplementation' deployed at ${bytecodes.address}`)
    }

    const implementation = await proxy.implementation()
    if (implementation.toLowerCase() !== bytecodes.address.toLowerCase()) {
      console.info()
      console.info("   > WitnetBytecodesImplementation:", bytecodes.address, `(v${await bytecodes.version()})`)
      console.info("   > WitnetBytecodesProxy:", proxy.address)
      console.info("   > WitnetBytecodesProxy.implementation::", implementation)
      const answer = await utils.prompt("   > Upgrade the proxy ? [y/N] ")
      if (["y", "yes"].includes(answer.toLowerCase().trim())) {
        await proxy.upgradeTo(bytecodes.address, "0x")
        console.info("   > Done.")
      } else {
        console.info("   > Not upgraded.")
      }
    }
  }
}

function saveAddresses (addrs) {
  fs.writeFileSync(
    "./migrations/witnet.addresses.json",
    JSON.stringify(addrs, null, 4),
    { flag: "w+" }
  )
}
