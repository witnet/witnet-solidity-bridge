const ethUtils = require('ethereumjs-util');

const packageJson = require("../../package.json")
const singletons = require("../witnet.singletons") 
const utils = require("../../scripts/utils")

const Create2Factory = artifacts.require("Create2Factory")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")
const WitnetRandomness = artifacts.require("WitnetProxy")
const WitnetRandomnessImplementation = artifacts.require("WitnetRandomness")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  var addresses = require("../witnet.addresses")
  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  // Should the WitnetRandomness be deployed into this network:
  console.info()
  if (!isDryRun && addresses[ecosystem][network].WitnetRandomness == undefined) {
    console.info(`\n   WitnetPriceRouter: Not to be deployed into '${network}'`)
    return;
  }

  let proxy
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRandomness)) {
    var create2Factory = await Create2Factory.deployed()
    if(
      create2Factory && !utils.isNullAddress(create2Factory.address)
        && singletons?.WitnetRandomness
    ) {
      // Deploy the proxy via a singleton factory and a salt...
      const bytecode = WitnetRandomness.toJSON().bytecode
      const salt = singletons.WitnetRandomness?.salt 
        ? "0x" + ethUtils.setLengthLeft(
            ethUtils.toBuffer(
              singletons.WitnetRandomness.salt
            ), 32
          ).toString("hex")
        : "0x0"
      ;
      const proxyAddr = await create2Factory.determineAddr.call(bytecode, salt, { from })
      if ((await web3.eth.getCode(proxyAddr)).length <= 3) {
        // deploy instance only if not found in current network:
        utils.traceHeader(`Singleton inception of 'WitnetPriceRouter':`)
        const balance = await web3.eth.getBalance(from)
        const gas = singletons.WitnetRandomness.gas || 10 ** 6
        const tx = await create2Factory.deploy(bytecode, salt, { from, gas })
        utils.traceTx(
          tx.receipt,
          web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString())
        )
      } else {
        utils.traceHeader(`Singleton 'WitnetRandomness':`)
      }
      console.info("  ", "> proxy address:       ", proxyAddr)
      console.info("  ", "> proxy codehash:      ", web3.utils.soliditySha3(await web3.eth.getCode(proxyAddr)))        
      console.info("  ", "> proxy inception salt:", salt)
      proxy = await WitnetRandomness.at(proxyAddr)
    } else {
      // Deploy no singleton proxy ...
      await deployer.deploy(WitnetRandomness, { from })
      proxy = await WitnetRandomness.deployed()
    }
    addresses[ecosystem][network].WitnetRandomness = proxy.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    proxy = await WitnetRandomness.at(addresses[ecosystem][network].WitnetRandomness)
    console.info(`   Skipped: 'WitnetRandomness' deployed at ${proxy.address}`)
  }

  var randomness
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRandomnessImplementation)) {
    await deployer.deploy(
      WitnetRandomnessImplementation,
      WitnetRequestBoard.address,
      true,
      utils.fromAscii(packageJson.version),
      { from }
    )
    randomness = await WitnetRandomnessImplementation.deployed()
    addresses[ecosystem][network].WitnetRandomnessImplementation = randomness.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    randomness = await WitnetRandomnessImplementation.at(addresses[ecosystem][network].WitnetRandomnessImplementation)
    console.info(`   Skipped: 'WitnetRandomnessImplementation' deployed at ${randomness.address}`)
  }

  const implementation = await proxy.implementation()
  if (implementation.toLowerCase() !== randomness.address.toLowerCase()) {
    console.info()
    console.info("   > WitnetRandomness proxy:", proxy.address)
    console.info("   > WitnetRandomness implementation:", implementation)
    console.info("   > WitnetRandomnessImplementation:", randomness.address, `(v${await randomness.version()})`)
    if (
      isDryRun ||
        ["y", "yes"].includes((await utils.prompt("   > Upgrade the proxy ? [y/N] ")).toLowerCase().trim())
    ) {
      try {
        var tx = await proxy.upgradeTo(randomness.address, "0x", { from })
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
  WitnetRandomnessImplementation.address = proxy.address
}
