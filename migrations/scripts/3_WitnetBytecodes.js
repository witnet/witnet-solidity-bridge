const ethUtils = require("ethereumjs-util")
const { merge } = require("lodash")

const addresses = require("../witnet.addresses")
const settings = require("../witnet.settings")
const singletons = require("../witnet.salts")
const utils = require("../../scripts/utils")
const version = `${
  require("../../package").version
}-${
  require("child_process").execSync("git rev-parse HEAD").toString().trim().substring(0, 7)
}`

const Create2Factory = artifacts.require("Create2Factory")
const WitnetProxy = artifacts.require("WitnetProxy")

const WitnetBytecodes = artifacts.require("WitnetBytecodes")
const WitnetEncodingLib = artifacts.require("WitnetEncodingLib")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  const artifactNames = merge(settings.artifacts.default, settings.artifacts[ecosystem], settings.artifacts[network])
  const WitnetBytecodesImplementation = artifacts.require(artifactNames.WitnetBytecodes)

  let proxy
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetBytecodes)) {
    const factory = await Create2Factory.deployed()
    if (
      factory && !utils.isNullAddress(factory.address) &&
        singletons?.WitnetBytecodes
    ) {
      // Deploy the proxy via a singleton factory and a salt...
      const bytecode = WitnetProxy.toJSON().bytecode
      const salt = singletons.WitnetBytecodes?.salt
        ? "0x" + ethUtils.setLengthLeft(
          ethUtils.toBuffer(
            singletons.WitnetBytecodes.salt
          ), 32
        ).toString("hex")
        : "0x0"

      const proxyAddr = await factory.determineAddr.call(bytecode, salt, { from })
      if ((await web3.eth.getCode(proxyAddr)).length <= 3) {
        // deploy instance only if not found in current network:
        utils.traceHeader("Singleton inception of 'WitnetBytecodes':")
        const balance = await web3.eth.getBalance(from)
        const gas = singletons.WitnetBytecodes.gas
        const tx = await factory.deploy(bytecode, salt, { from, gas })
        utils.traceTx(
          tx.receipt,
          web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString())
        )
      } else {
        utils.traceHeader("Singleton 'WitnetBytecodes':")
      }
      console.info("  ", "> proxy address:       ", proxyAddr)
      console.info("  ", "> proxy codehash:      ", web3.utils.soliditySha3(await web3.eth.getCode(proxyAddr)))
      console.info("  ", "> proxy inception salt:", salt)
      proxy = await WitnetProxy.at(proxyAddr)
    } else {
      // Deploy no singleton proxy ...
      proxy = await WitnetProxy.new({ from })
    }
    addresses[ecosystem][network].WitnetBytecodes = proxy.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    proxy = await WitnetProxy.at(addresses[ecosystem][network].WitnetBytecodes)
    console.info(`   Skipped: 'WitnetBytecodes' deployed at ${proxy.address}`)
  }
  WitnetBytecodes.address = proxy.address

  let bytecodes
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetBytecodesImplementation)) {
    await deployer.link(WitnetEncodingLib, [WitnetBytecodesImplementation])
    await deployer.deploy(
      WitnetBytecodesImplementation,
      /* _isUpgradeable */ true,
      /* _versionTag    */ utils.fromAscii(version),
      { from }
    )
    bytecodes = await WitnetBytecodesImplementation.deployed()
    addresses[ecosystem][network].WitnetBytecodesImplementation = bytecodes.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    bytecodes = await WitnetBytecodesImplementation.at(addresses[ecosystem][network].WitnetBytecodesImplementation)
    console.info(`   Skipped: '${WitnetBytecodesImplementation.contractName}' deployed at ${bytecodes.address}`)
    console.info()
    WitnetBytecodesImplementation.address = bytecodes.address
    await deployer.link(WitnetEncodingLib, WitnetBytecodesImplementation)
  }

  const implementation = await proxy.implementation.call()
  if (implementation.toLowerCase() !== bytecodes.address.toLowerCase()) {
    const header = `Upgrading 'WitnetBytecodes' at ${proxy.address}...`
    console.info()
    console.info("  ", header)
    console.info("  ", "-".repeat(header.length))
    console.info()
    console.info("   > old implementation:", implementation)
    console.info("   > new implementation:", bytecodes.address, `(v${await bytecodes.version.call({ from })})`)
    if (
      isDryRun ||
        ["y", "yes"].includes((await utils.prompt("   > Upgrade the proxy ? [y/N] ")).toLowerCase().trim())
    ) {
      try {
        const tx = await proxy.upgradeTo(bytecodes.address, "0x", { from })
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
}
