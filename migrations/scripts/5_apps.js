const ethUtils = require("ethereumjs-util")
const settings = require("../../settings")
const utils = require("../../src/utils")

const WitnetDeployer = artifacts.require("WitnetDeployer")

module.exports = async function (_, network, [, from]) {
  const specs = settings.getSpecs(network)
  const targets = settings.getArtifacts(network)

  // Community appliances built on top of the Witnet Oracle are meant to be immutable,
  // and therefore not upgradable. Appliances can only be deployed
  // once all core Witnet Oracle artifacts get deployed and initialized.

  // ==========================================================================
  // --- WitnetRandomnessV2 --------------------------------------------------

  await deploy({
    network,
    targets,
    from: utils.isDryRun(network) ? from : specs.WitnetRandomness.from || from,
    key: "WitnetRandomness",
    specs: specs.WitnetRandomness,
    intrinsics: {
      types: ["address"],
      values: [
        /* _witnet */ await determineProxyAddr(from, specs.WitnetOracle?.vanity || 3),
      ],
    },
  })
}

async function deploy (target) {
  const { from, key, intrinsics, network, specs, targets } = target
  const { libs, immutables, vanity } = specs
  const salt = vanity ? "0x" + utils.padLeft(vanity.toString(16), "0", 64) : "0x0"

  const addresses = await utils.readJsonFromFile("./migrations/addresses.json")
  if (!addresses[network]) addresses[network] = {}

  const selection = utils.getWitnetArtifactsFromArgs()
  const artifact = artifacts.require(key)
  const contract = artifacts.require(targets[key])
  if (
    addresses[network][targets[key]] === "" ||
      selection.includes(key) ||  
      (libs && selection.filter(item => libs.includes(item)).length > 0) || 
      (!utils.isNullAddress(addresses[network][targets[key]]) && (
        await web3.eth.getCode(addresses[network][targets[key]])).length < 3
      )
  ) {
    utils.traceHeader(`Deploying '${key}'...`)
    console.info("  ", "> account:          ", from)
    console.info("  ", "> balance:          ", web3.utils.fromWei(await web3.eth.getBalance(from), "ether"), "ETH")
    const deployer = await WitnetDeployer.deployed()
    let { types, values } = intrinsics
    if (immutables?.types) types = [...types, ...immutables.types]
    if (immutables?.values) values = [...values, ...immutables.values]
    const constructorArgs = web3.eth.abi.encodeParameters(types, values)
    if (constructorArgs.length > 2) {
      console.info("  ", "> constructor types:", JSON.stringify(types))
      console.info("  ", "> constructor args: ", constructorArgs.slice(2))
    }
    const bytecode = link(contract.toJSON().bytecode, libs, targets)
    if (bytecode.indexOf("__") > -1) {
      console.info(bytecode)
      console.info("Error: Cannot deploy due to some missing libs")
      process.exit(1)
    }
    const initCode = bytecode + constructorArgs.slice(2)
    const addr = await deployer.determineAddr.call(initCode, salt, { from })
    const tx = await deployer.deploy(initCode, salt || "0x0", { from })
    utils.traceTx(tx)
    if ((await web3.eth.getCode(addr)).length > 3) {
      addresses[network][targets[key]] = addr
    } else {
      console.info(`Error: Contract was not deployed on expected address: ${addr}`)
      process.exit(1)
    }
    // save addresses file if required
    if (!utils.isDryRun(network)) {
      await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
      const args = await utils.readJsonFromFile("./migrations/constructorArgs.json")
      if (!args[network]) args[network] = {}
      args[network][targets[key]] = constructorArgs.slice(2)
      await utils.overwriteJsonFile("./migrations/constructorArgs.json", args)
    }
  } else if (addresses[network][key]) {
    utils.traceHeader(`Skipped '${key}'`)
  }
  if (!utils.isNullAddress(addresses[network][targets[key]])) {
    artifact.address = addresses[network][targets[key]]
    contract.address = addresses[network][targets[key]]
    for (const index in libs) {
      const libname = libs[index]
      const lib = artifacts.require(libname)
      contract.link(lib)
      console.info("  ", "> external library:  ", `${libname}@${lib.address}`)
    };
    const appliance = await artifact.deployed()
    console.info("  ", "> appliance address: ", appliance.address)
    console.info("  ", "> appliance class:   ", await appliance.class({ from }))
    console.info("  ", "> appliance codehash:", web3.utils.soliditySha3(await web3.eth.getCode(appliance.address)))
    console.info("  ", "> appliance specs:   ", await appliance.specs({ from }))
    console.info()
  }
  return contract
}

async function determineProxyAddr (from, nonce) {
  const salt = nonce ? "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(nonce), 32).toString("hex") : "0x0"
  const deployer = await WitnetDeployer.deployed()
  return await deployer.determineProxyAddr.call(salt, { from })
}

function link (bytecode, libs, targets) {
  if (libs && Array.isArray(libs) && libs.length > 0) {
    for (const index in libs) {
      const key = targets[libs[index]]
      const lib = artifacts.require(key)
      bytecode = bytecode.replaceAll(`__${key}${"_".repeat(38 - key.length)}`, lib.address.slice(2))
      console.info("  ", `> linked library:    ${key} => ${lib.address}`)
    }
  }
  return bytecode
}
