const fs = require("fs")
const settings = require("../../../settings")
const utils = require("../../../src/utils")

const WitnetDeployer = artifacts.require("WitnetDeployer")

module.exports = async function (truffleDeployer, network, [,,, master]) {
  const addresses = await utils.readJsonFromFile("./migrations/addresses.json")
  if (!addresses[network]) addresses[network] = {}

  const deployerAddr = utils.getNetworkBaseArtifactAddress(network, addresses, "WitnetDeployer")
  if (utils.isNullAddress(deployerAddr) || (await web3.eth.getCode(deployerAddr)).length < 3) {
    // Settle WitnetDeployer bytecode and source code as to guarantee
    // salted addresses remain as expected no matter if the solc version
    // is changed in migrations/witnet.settings.js
    const impl = settings.getArtifacts(network).WitnetDeployer
    utils.traceHeader("Defrosted 'WitnetDeployer'")
    fs.writeFileSync(
      `build/contracts/${impl}.json`,
      fs.readFileSync(`migrations/frosts/${impl}.json`),
      { encoding: "utf8", flag: "w" }
    )
    const WitnetDeployer = artifacts.require(impl)
    const metadata = JSON.parse(WitnetDeployer.metadata)
    console.info("  ", "> compiler:          ", metadata.compiler.version)
    console.info("  ", "> evm version:       ", metadata.settings.evmVersion.toUpperCase())
    console.info("  ", "> optimizer:         ", JSON.stringify(metadata.settings.optimizer))
    console.info("  ", "> source code path:  ", metadata.settings.compilationTarget)
    console.info("  ", "> artifact codehash: ", web3.utils.soliditySha3(WitnetDeployer.toJSON().deployedBytecode))
    await truffleDeployer.deploy(WitnetDeployer, {
      from: settings.getSpecs(network)?.WitnetDeployer?.from || web3.utils.toChecksumAddress(master),
    })
    addresses[network].WitnetDeployer = WitnetDeployer.address
    await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
  
  } else {
    WitnetDeployer.address = deployerAddr
    utils.traceHeader("Deployed 'WitnetDeployer'")
    console.info("  ", "> contract address:  \x1b[95m", WitnetDeployer.address, "\x1b[0m")
    console.info("  ", "> master address:    \x1b[35m", master, "\x1b[0m")
    console.info()
  }

  // Settle WitnetDeployer bytecode and source code as to guarantee
  // that proxified base artifacts can get automatically verified
  utils.traceHeader("Defrosting 'WitnetProxy'")
  fs.writeFileSync(
    "build/contracts/WitnetProxy.json",
    fs.readFileSync("migrations/frosts/WitnetProxy.json"),
    { encoding: "utf8", flag: "w" }
  )
  const WitnetProxy = artifacts.require("WitnetProxy")
  const metadata = JSON.parse(WitnetProxy.metadata)
  console.info("  ", "> compiler:          ", metadata.compiler.version)
  console.info("  ", "> evm version:       ", metadata.settings.evmVersion.toUpperCase())
  console.info("  ", "> optimizer:         ", JSON.stringify(metadata.settings.optimizer))
  console.info("  ", "> artifact codehash: ", web3.utils.soliditySha3(WitnetProxy.toJSON().deployedBytecode))
}
