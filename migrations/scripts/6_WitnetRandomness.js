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

const WitnetRandomness = artifacts.require("WitnetRandomness")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  console.info()
  if (!isDryRun && addresses[ecosystem][network].WitnetRandomness === undefined) {
    console.info(`\n   WitnetRandomness: Not to be deployed into '${network}'`)
    return
  }

  const create2Factory = await Create2Factory.deployed()

  const artifactNames = merge(settings.artifacts.default, settings.artifacts[ecosystem], settings.artifacts[network])
  const WitnetRandomnessImplementation = artifacts.require(artifactNames.WitnetRandomness)

  if (addresses[ecosystem][network].WitnetRandomnessImplementation !== undefined) {
    let proxy
    if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRandomness)) {
      if (
        create2Factory && !utils.isNullAddress(create2Factory.address) &&
          singletons?.WitnetRandomness
      ) {
        // Deploy the proxy via a singleton factory and a salt...
        const bytecode = WitnetProxy.toJSON().bytecode
        const salt = singletons.WitnetRandomness?.salt
          ? "0x" + ethUtils.setLengthLeft(
            ethUtils.toBuffer(
              singletons.WitnetRandomness.salt
            ), 32
          ).toString("hex")
          : "0x0"

        const proxyAddr = await create2Factory.determineAddr.call(bytecode, salt, { from })
        if ((await web3.eth.getCode(proxyAddr)).length <= 3) {
          // deploy instance only if not found in current network:
          utils.traceHeader("Singleton inception of 'WitnetRandomness':")
          const balance = await web3.eth.getBalance(from)
          const gas = singletons.WitnetRandomness.gas
          const tx = await create2Factory.deploy(bytecode, salt, { from, gas })
          utils.traceTx(
            tx.receipt,
            web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString())
          )
        } else {
          utils.traceHeader("Singleton 'WitnetRandomness':")
        }
        console.info("  ", "> proxy address:       ", proxyAddr)
        console.info("  ", "> proxy codehash:      ", web3.utils.soliditySha3(await web3.eth.getCode(proxyAddr)))
        console.info("  ", "> proxy inception salt:", salt)
        proxy = await WitnetProxy.at(proxyAddr)
      } else {
        // Deploy no singleton proxy ...
        proxy = await WitnetProxy.new({ from })
      }
      addresses[ecosystem][network].WitnetRandomness = proxy.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      proxy = await WitnetProxy.at(addresses[ecosystem][network].WitnetRandomness)
      console.info(`   Skipped: 'WitnetRandomness' deployed at ${proxy.address}`)
    }
    WitnetRandomness.address = proxy.address

    let randomness
    if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRandomnessImplementation)) {
      await deployer.deploy(
        WitnetRandomnessImplementation,
        WitnetRequestBoard.address,
        /* _versionTag    */ utils.fromAscii(version),
        { from }
      )
      randomness = await WitnetRandomnessImplementation.deployed()
      addresses[ecosystem][network].WitnetRandomnessImplementation = randomness.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      randomness = await WitnetRandomnessImplementation.at(
        addresses[ecosystem][network].WitnetRandomnessImplementation
      )
      console.info(`   Skipped: '${WitnetRandomnessImplementation.contractName}' deployed at ${randomness.address}`)
      WitnetRandomnessImplementation.address = randomness.address
    }

    const implementation = await proxy.implementation()
    if (implementation.toLowerCase() !== randomness.address.toLowerCase()) {
      const header = `Upgrading 'WitnetRandomness' at ${proxy.address}...`
      console.info()
      console.info("  ", header)
      console.info("  ", "-".repeat(header.length))
      console.info()
      console.info("   > old implementation:", implementation)
      console.info("   > new implementation:", randomness.address, `(v${await randomness.version.call({ from })})`)
      if (
        isDryRun ||
          ["y", "yes"].includes((await utils.prompt("   > Upgrade the proxy ? [y/N] ")).toLowerCase().trim())
      ) {
        try {
          const tx = await proxy.upgradeTo(randomness.address, "0x", { from })
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
  } else {
    if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRandomness)) {
      // deploy unproxified WitnetRandomness contract
      await deployer.deploy(
        WitnetRandomnessImplementation,
        WitnetRequestBoard.address,
        utils.fromAscii(version),
        { from }
      )
      addresses[ecosystem][network].WitnetRandomness = WitnetRandomnessImplementation.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      WitnetRandomnessImplementation.address = addresses[ecosystem][network]?.WitnetRandomness
      console.info(`   Skipped: unproxied 'WitnetRandomness' deployed at ${WitnetRandomnessImplementation.address}`)
    }
    WitnetRandomness.address = WitnetRandomnessImplementation.address
  }
}
