const ethUtils = require("ethereumjs-util")
const settings = require("../../settings")
const utils = require("../../src/utils")
const version = `${
  require("../../package").version
}-${
  require("child_process").execSync("git rev-parse HEAD").toString().trim().substring(0, 7)
}`

const WitnetDeployer = artifacts.require("WitnetDeployer")

module.exports = async function (_, network, [, from]) {
  const specs = settings.getSpecs(network)
  const targets = settings.getArtifacts(network)

  // ==========================================================================
  // --- WitnetRadonRegistry core implementation ---------------------------

  await deploy({
    network,
    targets,
    from: utils.isDryRun(network) ? from : specs.WitnetRadonRegistry.from || from,
    key: targets.WitnetRadonRegistry,
    libs: specs.WitnetRadonRegistry.libs,
    immutables: specs.WitnetRadonRegistry.immutables,
    intrinsics: {
      types: ["bool", "bytes32"],
      values: [
        /* _upgradable */ true,
        /* _versionTag */ utils.fromAscii(version),
      ],
    },
  })

  // ==========================================================================
  // --- WitnetRequestFactory core implementation -----------------------------

  await deploy({
    network,
    targets,
    from: utils.isDryRun(network) ? from : specs.WitnetRequestFactory.from || from,
    key: targets.WitnetRequestFactory,
    libs: specs.WitnetRequestFactory.libs,
    immutables: specs.WitnetRequestFactory.immutables,
    intrinsics: {
      types: ["address", "address", "bool", "bytes32"],
      values: [
        /* _witnet     */ await determineProxyAddr(from, specs.WitnetOracle?.vanity || 3),
        /* _registry   */ await determineProxyAddr(from, specs.WitnetRadonRegistry?.vanity || 1),
        /* _upgradable */ true,
        /* _versionTag */ utils.fromAscii(version),
      ],
    },
  })

  // ==========================================================================
  // --- WitnetOracle core implementation ---------------------------------

  await deploy({
    network,
    targets,
    from: utils.isDryRun(network) ? from : specs.WitnetOracle.from || from,
    key: targets.WitnetOracle,
    libs: specs.WitnetOracle.libs,
    immutables: specs.WitnetOracle.immutables,
    intrinsics: {
      types: ["address", "address", "bool", "bytes32"],
      values: [
        /* _factory    */ await determineProxyAddr(from, specs.WitnetRequestFactory?.vanity || 2),
        /* _registry   */ await determineProxyAddr(from, specs.WitnetRadonRegistry?.vanity || 1),
        /* _upgradable */ true,
        /* _versionTag */ utils.fromAscii(version),
      ],
    },
  })

  // ==========================================================================
  // --- WitnetPriceFeeds core implementation ---------------------------------

  await deploy({
    network,
    targets,
    from: utils.isDryRun(network) ? from : specs.WitnetPriceFeeds.from || from,
    key: targets.WitnetPriceFeeds,
    libs: specs.WitnetPriceFeeds.libs,
    immutables: specs.WitnetPriceFeeds.immutables,
    intrinsics: {
      types: ["address", "bool", "bytes32"],
      values: [
        /* _witnet     */ await determineProxyAddr(from, specs.WitnetOracle?.vanity || 3),
        /* _upgradable */ true,
        /* _versionTag */ utils.fromAscii(version),
      ],
    },
  })
}

async function deploy (specs) {
  const { from, key, libs, intrinsics, immutables, network, targets } = specs

  const addresses = await utils.readJsonFromFile("./migrations/addresses.json")
  if (!addresses[network]) addresses[network] = {}

  const selection = utils.getWitnetArtifactsFromArgs()

  const contract = artifacts.require(key)
  if (
    utils.isNullAddress(addresses[network][key]) ||
      (await web3.eth.getCode(addresses[network][key])).length < 3 ||
      selection.includes(key) ||
      (libs && selection.filter(item => libs.includes(item)).length > 0)
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
    const coreBytecode = link(contract.toJSON().bytecode, libs, targets)
    if (coreBytecode.indexOf("__") > -1) {
      console.info(coreBytecode)
      console.info("Error: Cannot deploy due to some missing libs")
      process.exit(1)
    }
    const coreInitCode = coreBytecode + constructorArgs.slice(2)
    const coreAddr = await deployer.determineAddr.call(coreInitCode, "0x0", { from })
    const tx = await deployer.deploy(coreInitCode, "0x0", { from })
    utils.traceTx(tx)
    if ((await web3.eth.getCode(coreAddr)).length > 3) {
      addresses[network][key] = coreAddr
    } else {
      console.info(`Error: Contract was not deployed on expected address: ${coreAddr}`)
      process.exit(1)
    }
    // save addresses file if required
    if (!utils.isDryRun(network)) {
      await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
      const args = await utils.readJsonFromFile("./migrations/constructorArgs.json")
      if (!args?.default[key] || constructorArgs.slice(2) !== args.default[key]) {
        if (!args[network]) args[network] = {}
        args[network][key] = constructorArgs.slice(2)
        await utils.overwriteJsonFile("./migrations/constructorArgs.json", args)
      }
    }
  } else {
    utils.traceHeader(`Skipped '${key}'`)
  }
  contract.address = addresses[network][key]
  for (const index in libs) {
    const libname = libs[index]
    const lib = artifacts.require(libname)
    contract.link(lib)
    console.info("  ", "> external library: ", `${libname}@${lib.address}`)
  };
  console.info("  ", "> contract address: ", contract.address)
  console.info("  ", "> contract codehash:", web3.utils.soliditySha3(await web3.eth.getCode(contract.address)))
  console.info()
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
