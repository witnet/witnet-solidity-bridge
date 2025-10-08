const settings = require("../../../settings/index").default
const utils = require("../../../src/utils").default

module.exports = async function (deployer, network, [, from]) {
  const addresses = await utils.readJsonFromFile("./migrations/addresses.json")
  if (!addresses[network]) addresses[network] = {}
  if (!addresses[network]?.libs) addresses[network].libs = {}

  const networkArtifacts = settings.getArtifacts(network)
  const selection = utils.getWitnetArtifactsFromArgs()

  for (const index in networkArtifacts.libs) {
    const base = networkArtifacts.libs[index]
    const impl = networkArtifacts.libs[base]
    let libNetworkAddr = utils.getNetworkLibsArtifactAddress(network, addresses, impl)

    if (
      process.argv.includes("--artifacts") 
      && process.argv.includes("--compile-none")
      && !process.argv.includes("--upgrade-all") 
      && !selection.includes(impl) 
      && !selection.includes(base)
    ) {
      utils.traceHeader(`Skipped '${impl}`)
      console.info(`   > library address:    \x1b[92m${libNetworkAddr}\x1b[0m`)
      continue;
    }
    
    const libImplArtifact = artifacts.require(impl)
    let bytecodeChanged = false
    try {
      const networkCode = (await web3.eth.getCode(libNetworkAddr)).slice(0, -86)
      let targetCode = libImplArtifact.toJSON().deployedBytecode
      targetCode = targetCode.slice(0,4) + libNetworkAddr.slice(2).toLowerCase() + targetCode.slice(44, -86)
      if (targetCode !== networkCode) {
        bytecodeChanged = true
      }
    } catch (err) {
      console.error(`Cannot get code from ${libNetworkAddr}: ${err}`)
    }
    
    if (
      // lib implementation artifact is listed as --artifacts on CLI 
      selection.includes(impl) || selection.includes(base) ||
      // or, no address found in addresses file, or no actual code deployed there
      utils.isNullAddress(libNetworkAddr) || 
      // or. --libs specified on CLI
      (process.argv.includes("--upgrade-all") /*&& libTargetAddr !== libNetworkAddr*/)
    ) {
      if (utils.isNullAddress(libNetworkAddr) || bytecodeChanged) {
        await deployer.deploy(libImplArtifact, { from })      
        addresses[network].libs[impl] = libImplArtifact.address
        libNetworkAddr = libTargetAddr
        await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
      } else {
        utils.traceHeader(`Skipping '${impl}': no changes in deployed bytecode.`)
      }
    } else {
      utils.traceHeader(`Deployed '${impl}'`)
    }
    
    // settle Truffle artifact address to the one found in file:
    libImplArtifact.address = utils.getNetworkLibsArtifactAddress(network, addresses, impl)
    
    if (bytecodeChanged) {
      console.info(`   > library address:   \x1b[30;43m${libImplArtifact.address}\x1b[0m`)
    } else {
      console.info("   > library address:   \x1b[92m", libImplArtifact.address, "\x1b[0m")
    }
    console.info()
  }
}
