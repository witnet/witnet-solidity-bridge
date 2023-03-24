const ethUtils = require("ethereumjs-util")
const { merge } = require("lodash")

const settings = require("../witnet.settings")
const singletons = require("../witnet.singletons") 
const utils = require("../../scripts/utils")

const Create2Factory = artifacts.require("Create2Factory")
const WitnetLib = artifacts.require("WitnetLib")
const WitnetProxy = artifacts.require("WitnetProxy")
const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")

module.exports = async function (deployer, network, [, from, reporter]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  var addresses = require("../witnet.addresses")
  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  const realm = network === "test" || network === "develop"
    ? "default"
    : utils.getRealmNetworkFromArgs()[0]

  const artifactsName = merge(settings.artifacts.default, settings.artifacts[realm])
  const WitnetRequestBoardImplementation = artifacts.require(artifactsName.WitnetRequestBoard)
  
  var board
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRequestBoardImplementation)) {
    await deployer.link(WitnetLib, WitnetRequestBoardImplementation);
    await deployer.deploy(
      WitnetRequestBoardImplementation,
      ...(
        // if defined, use network-specific constructor parameters:
        settings.constructorParams[network]?.WitnetRequestBoard ||
          // otherwise, use realm-specific parameters, if any:
          settings.constructorParams[realm]?.WitnetRequestBoard ||
          // or, default defined parameters for WRBs, if any:
          settings.constructorParams?.default?.WitnetRequestBoard
      ), 
      { from }
    )
    board = await WitnetRequestBoardImplementation.deployed()
    addresses[ecosystem][network].WitnetRequestBoardImplementation = board.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    board = await WitnetRequestBoardImplementation.at(addresses[ecosystem][network].WitnetRequestBoardImplementation)
    utils.traceHeader(`Skipping '${artifactsName.WitnetRequestBoard}'`)
    console.info("  ", "> contract address:", board.address)
    console.info()
  }

  var proxy
  const factory = await Create2Factory.deployed()
  if (utils.isNullAddress(addresses[ecosystem][network]?.WitnetRequestBoard)) {
    if(
      factory && !utils.isNullAddress(factory.address)
        && singletons?.WitnetRequestBoard
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
      ;
      const proxyAddr = await factory.determineAddr.call(bytecode, salt, { from })
      if ((await web3.eth.getCode(proxyAddr)).length <= 3) {
        // deploy instance only if not found in current network:
        utils.traceHeader(`Singleton inception of 'WitnetRequestBoard':`)
        const balance = await web3.eth.getBalance(from)
        const gas = singletons.WitnetRequestBoard.gas || 10 ** 6
        const tx = await factory.deploy(bytecode, salt, { from, gas })
        utils.traceTx(
          tx.receipt,
          web3.utils.fromWei((balance - await web3.eth.getBalance(from)).toString())
        )
      } else {
        utils.traceHeader(`Singleton 'WitnetRequestBoard':`)
      }
      console.info("  ", "> proxy address:       ", proxyAddr)
      console.info("  ", "> proxy codehash:      ", web3.utils.soliditySha3(await web3.eth.getCode(proxyAddr)))        
      console.info("  ", "> proxy inception salt:", salt)
      proxy = await WitnetProxy.at(proxyAddr)
    } else {
      // Deploy no singleton proxy ...
      await deployer.deploy(WitnetProxy, { from })
      proxy = await WitnetProxy.deployed()
    }
    // update addresses file      
    addresses[ecosystem][network].WitnetRequestBoard = proxy.address
    if (!isDryRun) {
      utils.saveAddresses(addresses)
    }
  } else {
    proxy = await WitnetProxy.at(addresses[ecosystem][network].WitnetRequestBoard)
    utils.traceHeader("Skipping 'WitnetRequestBoard'")
    console.info("  ", "> proxy address:", proxy.address)
    console.info()
  }
  WitnetRequestBoard.address = proxy.address

  var implementation = await proxy.implementation.call({ from })
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
            [ reporter, ],
          ),
          { from }
        )
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
  WitnetRequestBoardImplementation.address = proxy.address
}