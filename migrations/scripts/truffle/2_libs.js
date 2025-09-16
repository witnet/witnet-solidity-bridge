const settings = require("../../../settings/index.cjs")
const utils = require("../../../src/utils.cjs")

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
      process.argv.includes("--artifacts") &&
      process.argv.includes("--compile-none") &&
      !process.argv.includes("--libs") &&
      !selection.includes(impl) &&
      !selection.includes(base)
    ) {
      utils.traceHeader(`Skipped '${impl}`)
      console.info(`   > library address:    \x1b[92m${libNetworkAddr}\x1b[0m`)
      continue
    }
    const libImplArtifact = artifacts.require(impl)
    if (
      // lib implementation artifact is listed as --artifacts on CLI
      selection.includes(impl) || selection.includes(base) ||
      // or, no address found in addresses file, or no actual code deployed there
      (utils.isNullAddress(libNetworkAddr) || (await web3.eth.getCode(libNetworkAddr)).length < 3) ||
      // or, --libs specified on CLI
      (process.argv.includes("--libs"))
    ) {
      await deployer.deploy(libImplArtifact, { from }) 
      addresses[network].libs[impl] = libImplArtifact.address
      await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
    } else {
      utils.traceHeader(`Deployed '${impl}'`)
    }
    libImplArtifact.address = utils.getNetworkLibsArtifactAddress(network, addresses, impl)
    console.info("   > library address:   \x1b[92m", libImplArtifact.address, "\x1b[0m")
    console.info()
  }
}
