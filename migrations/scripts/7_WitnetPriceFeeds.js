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

const WitnetPriceFeeds = artifacts.require("WitnetPriceFeeds")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")

module.exports = async function (deployer, network, [, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  console.info()
  if (!isDryRun && addresses[ecosystem][network].WitnetPriceFeeds === undefined) {
    console.info(`\n   WitnetPriceFeeds: Not to be deployed into '${network}'`)
    return
  }

  const artifactNames = merge(settings.artifacts.default, settings.artifacts[ecosystem], settings.artifacts[network])
  const WitnetPriceFeedsImplementation = artifacts.require(artifactNames.WitnetPriceFeeds)

  if (addresses[ecosystem][network]?.WitnetPriceFeedsImplementation !== undefined || isDryRun) {
    let proxy
    if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetPriceFeeds)) {
      const create2Factory = await Create2Factory.deployed()
      if (
        create2Factory && !utils.isNullAddress(create2Factory.address) &&
          singletons?.WitnetPriceFeeds
      ) {
        // Deploy the proxy via a singleton factory and a salt...
        const bytecode = WitnetProxy.toJSON().bytecode
        const salt = singletons.WitnetPriceFeeds?.salt
          ? "0x" + ethUtils.setLengthLeft(
            ethUtils.toBuffer(
              singletons.WitnetPriceFeeds.salt
            ), 32
          ).toString("hex")
          : "0x0"

        const proxyAddr = await create2Factory.determineAddr.call(bytecode, salt, { from })
        if ((await web3.eth.getCode(proxyAddr)).length <= 3) {
          // deploy instance only if not found in current network:
          utils.traceHeader("Singleton inception of 'WitnetPriceFeeds':")
          const balance = await web3.eth.getBalance(from)
          const gas = singletons.WitnetPriceFeeds.gas || 10 ** 6
          const tx = await create2Factory.deploy(bytecode, salt, { from, gas })
          utils.traceTx(
            tx.receipt,
            web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString())
          )
        } else {
          utils.traceHeader("Singleton 'WitnetPriceFeeds':")
        }
        console.info("  ", "> proxy address:       ", proxyAddr)
        console.info("  ", "> proxy codehash:      ", web3.utils.soliditySha3(await web3.eth.getCode(proxyAddr)))
        console.info("  ", "> proxy inception salt:", salt)
        proxy = await WitnetProxy.at(proxyAddr)
      } else {
        // Deploy no singleton proxy ...
        proxy = await WitnetProxy.new({ from })
      }
      addresses[ecosystem][network].WitnetPriceFeeds = proxy.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      proxy = await WitnetProxy.at(addresses[ecosystem][network].WitnetPriceFeeds)
      console.info(`   Skipped: 'WitnetPriceFeeds' deployed at ${proxy.address}`)
    }

    let router
    if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetPriceFeedsImplementation)) {
      if (WitnetPriceFeedsImplementation.contractName === "WitnetPriceRouter") {
        await deployer.deploy(
          WitnetPriceFeedsImplementation,
          true,
          utils.fromAscii(version),
          { from }
        )
      } else {
        await deployer.deploy(
          WitnetPriceFeedsImplementation,
          WitnetRequestBoard.address,
          true,
          utils.fromAscii(version),
          { from }
        )
      }
      router = await WitnetPriceFeedsImplementation.deployed()
      addresses[ecosystem][network].WitnetPriceFeedsImplementation = router.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      router = await WitnetPriceFeedsImplementation.at(
        addresses[ecosystem][network].WitnetPriceFeedsImplementation
      )
      console.info(`   Skipped: '${WitnetPriceFeedsImplementation.contractName}' deployed at ${router.address}`)
      WitnetPriceFeedsImplementation.address = router.address
    }
    WitnetPriceFeeds.address = proxy.address

    const implementation = await proxy.implementation()
    if (implementation.toLowerCase() !== router.address.toLowerCase()) {
      const header = `Upgrading 'WitnetPriceFeeds' at ${proxy.address}...`
      console.info()
      console.info("  ", header)
      console.info("  ", "-".repeat(header.length))
      console.info()
      console.info("   > old implementation:", implementation)
      console.info("   > new implementation:", router.address, `(v${await router.version.call({ from })})`)
      if (
        isDryRun ||
          ["y", "yes"].includes((await utils.prompt("   > Upgrade the proxy ? [y/N] ")).toLowerCase().trim())
      ) {
        try {
          const tx = await proxy.upgradeTo(router.address, "0x", { from })
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
    if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetPriceFeeds)) {
      // deploy unproxified WitnetPriceFeeds contract
      await deployer.deploy(
        WitnetPriceFeedsImplementation,
        WitnetRequestBoard.address,
        false,
        utils.fromAscii(version),
        { from }
      )
      addresses[ecosystem][network].WitnetPriceFeeds = WitnetPriceFeedsImplementation.address
      if (!isDryRun) {
        utils.saveAddresses(addresses)
      }
    } else {
      WitnetPriceFeedsImplementation.address = addresses[ecosystem][network]?.WitnetPriceFeeds
      console.info(`   Skipped: unproxied 'WitnetPriceFeeds' deployed at ${WitnetPriceFeedsImplementation.address}`)
    }
    WitnetPriceFeeds.address = WitnetPriceFeedsImplementation.address
  }
}
