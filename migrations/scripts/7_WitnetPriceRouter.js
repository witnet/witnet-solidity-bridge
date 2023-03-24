const ethUtils = require('ethereumjs-util');

const packageJson = require("../../package.json")
const singletons = require("../witnet.singletons") 
const utils = require("../../scripts/utils")

const Create2Factory = artifacts.require("Create2Factory")
const WitnetPriceRouter = artifacts.require("WitnetProxy")
const WitnetPriceRouterImplementation = artifacts.require("WitnetPriceRouter")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  var addresses = require("../witnet.addresses")
  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  // Should the WitnetPriceRouter be deployed into this network:
  console.info()
  if (!isDryRun && addresses[ecosystem][network].WitnetPriceRouter == undefined) {
    console.info(`\n   WitnetPriceRouter: Not to be deployed into '${network}'`)
    return;
  }

  let proxy
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetPriceRouter)) {
    var create2Factory = await Create2Factory.deployed()
    if(
      create2Factory && !utils.isNullAddress(create2Factory.address)
        && singletons?.WitnetPriceRouter
    ) {
      // Deploy the proxy via a singleton factory and a salt...
      const bytecode = WitnetPriceRouter.toJSON().bytecode
      const salt = singletons.WitnetPriceRouter?.salt 
        ? "0x" + ethUtils.setLengthLeft(
            ethUtils.toBuffer(
              singletons.WitnetPriceRouter.salt
            ), 32
          ).toString("hex")
        : "0x0"
      ;
      const proxyAddr = await create2Factory.determineAddr.call(bytecode, salt, { from })
      if ((await web3.eth.getCode(proxyAddr)).length <= 3) {
        // deploy instance only if not found in current network:
        utils.traceHeader(`Singleton inception of 'WitnetPriceRouter':`)
        const balance = await web3.eth.getBalance(from)
        const gas = singletons.WitnetPriceRouter.gas || 10 ** 6
        const tx = await create2Factory.deploy(bytecode, salt, { from, gas })
        utils.traceTx(
          tx.receipt,
          web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString())
        )
      } else {
        utils.traceHeader(`Singleton 'WitnetPriceRouter':`)
      }
      console.info("  ", "> proxy address:       ", proxyAddr)
      console.info("  ", "> proxy codehash:      ", web3.utils.soliditySha3(await web3.eth.getCode(proxyAddr)))        
      console.info("  ", "> proxy inception salt:", salt)
      proxy = await WitnetPriceRouter.at(proxyAddr)
    } else {
      // Deploy no singleton proxy ...
      await deployer.deploy(WitnetPriceRouter, { from })
      proxy = await WitnetPriceRouter.deployed()
    }
    addresses[ecosystem][network].WitnetPriceRouter = proxy.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    proxy = await WitnetPriceRouter.at(addresses[ecosystem][network].WitnetPriceRouter)
    console.info(`   Skipped: 'WitnetPriceRouter' deployed at ${proxy.address}`)
  }

  var router
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetPriceRouterImplementation)) {
    await deployer.deploy(
      WitnetPriceRouterImplementation,
      true,
      utils.fromAscii(packageJson.version),
      { from }
    )
    router = await WitnetPriceRouterImplementation.deployed()
    addresses[ecosystem][network].WitnetPriceRouterImplementation = router.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    router = await WitnetPriceRouterImplementation.at(addresses[ecosystem][network].WitnetPriceRouterImplementation)
    console.info(`   Skipped: 'WitnetPriceRouterImplementation' deployed at ${router.address}`)
  }

  const implementation = await proxy.implementation()
  if (implementation.toLowerCase() !== router.address.toLowerCase()) {
    console.info()
    console.info("   > WitnetPriceRouter proxy:", proxy.address)
    console.info("   > WitnetPriceRouter implementation:", implementation)
    console.info("   > WitnetPriceRouterImplementation:", router.address, `(v${await router.version()})`)
    if (
      isDryRun ||
        ["y", "yes"].includes((await utils.prompt("   > Upgrade the proxy ? [y/N] ")).toLowerCase().trim())
    ) {
      try { 
        var tx = await proxy.upgradeTo(router.address, "0x", { from })
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
  WitnetPriceRouterImplementation.address = proxy.address
}