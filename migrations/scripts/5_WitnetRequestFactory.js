const ethUtils = require('ethereumjs-util');

const addresses = require("../witnet.addresses")
const singletons = require("../witnet.singletons") 
const thePackage = require("../../package")
const utils = require("../../scripts/utils")

const Create2Factory = artifacts.require("Create2Factory")
const WitnetBytecodes = artifacts.require("WitnetBytecodes")
const WitnetRequestFactory = artifacts.require("WitnetProxy")
const WitnetRequestFactoryImplementation = artifacts.require("WitnetRequestFactory")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  console.info()
  console.info()
  if (!isDryRun && addresses[ecosystem][network].WitnetRequestFactory == undefined) {
    console.info(`   WitnetRequestFactory: not to be deployed into '${network}`)
    return
  }

  let proxy
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRequestFactory)) {
    var create2Factory = await Create2Factory.deployed()
    if(
      create2Factory && !utils.isNullAddress(create2Factory.address)
        && singletons?.WitnetRequestFactory
    ) {
      // Deploy the proxy via a singleton factory and a salt...
      const bytecode = WitnetRequestFactory.toJSON().bytecode
      const salt = singletons.WitnetRequestFactory?.salt 
        ? "0x" + ethUtils.setLengthLeft(
            ethUtils.toBuffer(
              singletons.WitnetRequestFactory.salt
            ), 32
          ).toString("hex")
        : "0x0"
      ;
      const proxyAddr = await create2Factory.determineAddr.call(bytecode, salt, { from })
      if ((await web3.eth.getCode(proxyAddr)).length <= 3) {
        // deploy instance only if not found in current network:
        utils.traceHeader(`Singleton inception of 'WitnetRequestFactory':`)
        const balance = await web3.eth.getBalance(from)
        const gas = singletons.WitnetRequestFactory.gas || 10 ** 6
        const tx = await create2Factory.deploy(bytecode, salt, { from, gas })
        utils.traceTx(
          tx.receipt,
          web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString())
        )
      } else {
        utils.traceHeader(`Singleton 'WitnetRequestFactory':`)
      }
      console.info("  ", "> proxy address:       ", proxyAddr)
      console.info("  ", "> proxy codehash:      ", web3.utils.soliditySha3(await web3.eth.getCode(proxyAddr)))        
      console.info("  ", "> proxy inception salt:", salt)
      proxy = await WitnetRequestFactory.at(proxyAddr)
    } else {
      // Deploy no singleton proxy ...
      await deployer.deploy(WitnetRequestFactory, { from })
      proxy = await WitnetRequestFactory.deployed()
    }
    addresses[ecosystem][network].WitnetRequestFactory = proxy.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    proxy = await WitnetRequestFactory.at(addresses[ecosystem][network].WitnetRequestFactory)
    console.info(`   Skipped: 'WitnetRequestFactory' deployed at ${proxy.address}`)
  }

  var factory
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRequestFactoryImplementation)) {
    await deployer.deploy(
      WitnetRequestFactoryImplementation,
      addresses[ecosystem][network].WitnetBytecodes || WitnetBytecodes.address,
      true,
      utils.fromAscii(thePackage.version),
      { from }
    )
    factory = await WitnetRequestFactoryImplementation.deployed()
    addresses[ecosystem][network].WitnetRequestFactoryImplementation = factory.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    factory = await WitnetRequestFactoryImplementation.at(addresses[ecosystem][network].WitnetRequestFactoryImplementation)
    console.info(`   Skipped: 'WitnetRequestFactoryImplementation' deployed at ${factory.address}`)
  }

  const implementation = await proxy.implementation()
  if (implementation.toLowerCase() !== factory.address.toLowerCase()) {
    console.info()
    console.info("   > WitnetRequestFactory proxy:", proxy.address)
    console.info("   > WitnetRequestFactory implementation:", implementation)
    console.info("   > WitnetRequestFactoryImplementation:", factory.address, `(v${await factory.version()})`)
    if (
      isDryRun ||
        ["y", "yes"].includes((await utils.prompt("   > Upgrade the proxy ? [y/N] ")).toLowerCase().trim())
    ) {
      try {
        var tx = await proxy.upgradeTo(factory.address, "0x", { from })
        console.info("   => transaction hash :", tx.receipt.transactionHash)
        console.info("   => transaction gas  :", tx.receipt.gasUsed)
        console.info("   > Done.")
      } catch (ex) {
        console.info("   !! Cannot upgrade the proxy:")
        console.info(ex)
      }
    } else {
      console.info("   > Not upgraded.")
    }
  }
  WitnetRequestFactoryImplementation.address = proxy.address
}