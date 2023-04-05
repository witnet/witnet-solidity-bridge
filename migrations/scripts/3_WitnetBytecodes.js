const ethUtils = require('ethereumjs-util');

const addresses = require("../witnet.addresses")
const singletons = require("../witnet.singletons") 
const thePackage = require("../../package")
const utils = require("../../scripts/utils")

const Create2Factory = artifacts.require("Create2Factory")
const WitnetBytecodes = artifacts.require("WitnetProxy")
const WitnetBytecodesImplementation = artifacts.require("WitnetBytecodes")
const WitnetEncodingLib = artifacts.require("WitnetEncodingLib")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  console.info()
  if (!isDryRun && addresses[ecosystem][network].WitnetBytecodes == undefined) {
    console.info(`   WitnetBytecodes: not to be deployed into '${network}`)
    return
  }
  
  let proxy
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetBytecodes)) {
    var factory = await Create2Factory.deployed()
    if(
      factory && !utils.isNullAddress(factory.address)
        && singletons?.WitnetBytecodes
    ) {
      // Deploy the proxy via a singleton factory and a salt...
      const bytecode = WitnetBytecodes.toJSON().bytecode
      const salt = singletons.WitnetBytecodes?.salt 
        ? "0x" + ethUtils.setLengthLeft(
            ethUtils.toBuffer(
              singletons.WitnetBytecodes.salt
            ), 32
          ).toString("hex")
        : "0x0"
      ;
      const proxyAddr = await factory.determineAddr.call(bytecode, salt, { from })
      if ((await web3.eth.getCode(proxyAddr)).length <= 3) {
        // deploy instance only if not found in current network:
        utils.traceHeader(`Singleton inception of 'WitnetBytecodes':`)
        const balance = await web3.eth.getBalance(from)
        const gas = singletons.WitnetBytecodes.gas || 10 ** 6
        const tx = await factory.deploy(bytecode, salt, { from, gas })
        utils.traceTx(
          tx.receipt,
          web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString())
        )
      } else {
        utils.traceHeader(`Singleton 'WitnetBytecodes':`)
      }
      console.info("  ", "> proxy address:       ", proxyAddr)
      console.info("  ", "> proxy codehash:      ", web3.utils.soliditySha3(await web3.eth.getCode(proxyAddr)))        
      console.info("  ", "> proxy inception salt:", salt)
      proxy = await WitnetBytecodes.at(proxyAddr)
    } else {
      // Deploy no singleton proxy ...
      await deployer.deploy(WitnetBytecodes, { from })
      proxy = await WitnetBytecodes.deployed()
    }
    addresses[ecosystem][network].WitnetBytecodes = proxy.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    proxy = await WitnetBytecodes.at(addresses[ecosystem][network].WitnetBytecodes)
    console.info(`   Skipped: 'WitnetBytecodes' deployed at ${proxy.address}`)
  }
  WitnetBytecodes.address = proxy.address

  let bytecodes
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetBytecodesImplementation)) {
    await deployer.link(
      WitnetEncodingLib,
      [WitnetBytecodesImplementation]
    )
    await deployer.deploy(
      WitnetBytecodesImplementation,
      true,
      utils.fromAscii(thePackage.version),
      { from }
    )
    bytecodes = await WitnetBytecodesImplementation.deployed()
    addresses[ecosystem][network].WitnetBytecodesImplementation = bytecodes.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    bytecodes = await WitnetBytecodesImplementation.at(addresses[ecosystem][network].WitnetBytecodesImplementation)
    console.info(`   Skipped: 'WitnetBytecodesImplementation' deployed at ${bytecodes.address}`)
  }

  const implementation = await proxy.implementation()
  if (implementation.toLowerCase() !== bytecodes.address.toLowerCase()) {
    console.info()
    console.info("   > WitnetBytecodes proxy:", proxy.address)
    console.info("   > WitnetBytecodes implementation:", implementation)
    console.info("   > WitnetBytecodesImplementation:", bytecodes.address, `(v${await bytecodes.version()})`)
    if (
      isDryRun ||
        ["y", "yes"].includes((await utils.prompt("   > Upgrade the proxy ? [y/N] ")).toLowerCase().trim())
    ) {
      try {
        var tx = await proxy.upgradeTo(bytecodes.address, "0x", { from })
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
  WitnetBytecodesImplementation.address = proxy.address
}
