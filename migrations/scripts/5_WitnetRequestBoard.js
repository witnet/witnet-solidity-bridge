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

const WitnetErrorsLib = artifacts.require("WitnetErrorsLib")
const WitnetRequestFactory = artifacts.require("WitnetRequestFactory")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")

module.exports = async function (deployer, network, [, from, reporter]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  const artifactsName = merge(settings.artifacts.default, settings.artifacts[ecosystem], settings.artifacts[network])
  const WitnetRequestBoardImplementation = artifacts.require(artifactsName.WitnetRequestBoard)

  let proxy
  const factory = await Create2Factory.deployed()
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRequestBoard)) {
    if (
      factory && !utils.isNullAddress(factory.address) &&
        singletons?.WitnetRequestBoard
    ) {
      // Deploy the proxy via a singleton factory and a salt...
      const bytecode = WitnetProxy.toJSON().bytecode
      const salt = singletons.WitnetRequestBoard?.salt
        ? "0x" + ethUtils.setLengthLeft(
          ethUtils.toBuffer(
            singletons.WitnetRequestBoard.salt
          ), 32
        ).toString("hex")
        : "0x0"

      const proxyAddr = await factory.determineAddr.call(bytecode, salt, { from })
      if ((await web3.eth.getCode(proxyAddr)).length <= 3) {
        // deploy instance only if not found in current network:
        utils.traceHeader("Singleton inception of 'WitnetRequestBoard':")
        const balance = await web3.eth.getBalance(from)
        const gas = singletons.WitnetRequestBoard.gas
        const tx = await factory.deploy(bytecode, salt, { from, gas })
        utils.traceTx(
          tx.receipt,
          web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString())
        )
      } else {
        utils.traceHeader("Singleton 'WitnetRequestBoard':")
      }
      console.info("  ", "> proxy address:       ", proxyAddr)
      console.info("  ", "> proxy codehash:      ", web3.utils.soliditySha3(await web3.eth.getCode(proxyAddr)))
      console.info("  ", "> proxy inception salt:", salt)
      proxy = await WitnetProxy.at(proxyAddr)
    } else {
      // Deploy no singleton proxy ...
      proxy = await WitnetProxy.new({ from })
    }
    // update addresses file
    addresses[ecosystem][network].WitnetRequestBoard = proxy.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    proxy = await WitnetProxy.at(addresses[ecosystem][network].WitnetRequestBoard)
    console.info(`   Skipped: 'WitnetRequestBoard' deployed at ${proxy.address}`)
  }
  WitnetRequestBoard.address = proxy.address

  let board
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRequestBoardImplementation)) {
    if (WitnetRequestBoardImplementation.contractName === "WitnetRequestBoardBypass") {
      await deployer.deploy(
        WitnetRequestBoardImplementation,
        addresses[ecosystem][network]?.WitnetRequestBoardBypass,
        true,
        utils.fromAscii(version)
      )
    } else {
      await deployer.link(WitnetErrorsLib, WitnetRequestBoardImplementation)
      await deployer.deploy(
        WitnetRequestBoardImplementation,
        WitnetRequestFactory.address,
        /* _isUpgradeable */ true,
        /* _versionTag    */ utils.fromAscii(version),
        ...(
          // if defined, use network-specific constructor parameters:
          settings.constructorParams[network]?.WitnetRequestBoard ||
            // otherwise, use ecosystem-specific parameters, if any:
            settings.constructorParams[ecosystem]?.WitnetRequestBoard ||
            // or, default defined parameters for WRBs, if any:
            settings.constructorParams?.default?.WitnetRequestBoard
        ),
        { from }
      )
    }
    board = await WitnetRequestBoardImplementation.deployed()
    addresses[ecosystem][network].WitnetRequestBoardImplementation = board.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    board = await WitnetRequestBoardImplementation.at(addresses[ecosystem][network].WitnetRequestBoardImplementation)
    console.info(`   Skipped: '${WitnetRequestBoardImplementation.contractName}' deployed at ${board.address}`)
    console.info()
    WitnetRequestBoardImplementation.address = board.address
    await deployer.link(WitnetErrorsLib, WitnetRequestBoardImplementation)
  }

  const implementation = await proxy.implementation.call()
  if (implementation.toLowerCase() !== board.address.toLowerCase()) {
    const header = `Upgrading 'WitnetRequestBoard' at ${proxy.address}...`
    console.info()
    console.info("  ", header)
    console.info("  ", "-".repeat(header.length))
    console.info()
    console.info("   > old implementation:", implementation)
    console.info("   > new implementation:", board.address, `(v${await board.version.call({ from })})`)
    if (
      isDryRun ||
        ["y", "yes"].includes((await utils.prompt("   > Upgrade the proxy ? [y/N] ")).toLowerCase().trim())
    ) {
      try {
        const tx = await proxy.upgradeTo(
          board.address,
          web3.eth.abi.encodeParameter(
            "address[]",
            [reporter],
          ),
          { from }
        )
        console.info("   => Transaction hash :", tx.receipt.transactionHash)
        console.info("   => Transaction gas  :", tx.receipt.gasUsed)
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
