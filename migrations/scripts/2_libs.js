const settings = require("../../settings")
const utils = require("../../src/utils")

const WitnetDeployer = artifacts.require("WitnetDeployer")

module.exports = async function (_, network, [, from]) {
  const addresses = await utils.readJsonFromFile("./migrations/addresses.json")
  if (!addresses[network]) addresses[network] = {}
  if (!addresses[network]?.libs) addresses[network].libs = {}

  const deployer = await WitnetDeployer.deployed()
  const networkArtifacts = settings.getArtifacts(network)
  const selection = utils.getWitnetArtifactsFromArgs()

  for (const index in networkArtifacts.libs) {
    const base = networkArtifacts.libs[index]
    const impl = networkArtifacts.libs[base]
    const libImplArtifact = artifacts.require(impl)
    const libInitCode = libImplArtifact.toJSON().bytecode
    const libTargetAddr = await deployer.determineAddr.call(libInitCode, "0x0", { from })
    const libTargetCode = await web3.eth.getCode(libTargetAddr)
    let libNetworkAddr = utils.getNetworkLibsArtifactAddress(network, addresses, impl)
    if (
      // lib implementation artifact is listed as --artifacts on CLI
      selection.includes(impl) ||
      // or, no address found in addresses file but code is already deployed into target address
      (utils.isNullAddress(libNetworkAddr) && libTargetCode.length > 3) ||
      // or, address found in addresses file but no code currently deployed in such
      (await web3.eth.getCode(libNetworkAddr)).length < 3
    ) {
      if (libTargetCode.length < 3) {
        utils.traceHeader(`Deploying '${impl}'...`)
        utils.traceTx(await deployer.deploy(libInitCode, "0x0", { from }))
        if ((await web3.eth.getCode(libTargetAddr)).length < 3) {
          console.info(`Error: Library was not deployed on expected address: ${libTargetAddr}`)
          process.exit(1)
        }
      } else {
        utils.traceHeader(`Recovered '${impl}'`)
      }
      addresses[network].libs[impl] = libTargetAddr
      libNetworkAddr = libTargetAddr
      // if (!utils.isDryRun(network)) {
      await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
      // }
    } else {
      utils.traceHeader(`Deployed '${impl}'`)
    }
    libImplArtifact.address = utils.getNetworkLibsArtifactAddress(network, addresses, impl)
    if (libTargetAddr !== libNetworkAddr) {
      console.info("   > library address:   \x1b[96m", libImplArtifact.address, `\x1b[0m!== \x1b[30;43m${libTargetAddr}\x1b[0m`)
    } else {
      console.info("   > library address:   \x1b[96m", libImplArtifact.address, "\x1b[0m")
    }
    console.info()
  }
}
