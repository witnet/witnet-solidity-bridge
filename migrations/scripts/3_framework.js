const ethUtils = require("ethereumjs-util")
const merge = require("lodash.merge")
const settings = require("../../settings")
const utils = require("../../src/utils")
const version = `${
  require("../../package").version
}-${
  require("child_process").execSync("git rev-parse HEAD").toString().trim().substring(0, 7)
}`

const selection = utils.getWitnetArtifactsFromArgs()

const WitnetDeployer = artifacts.require("WitnetDeployer")
const WitnetProxy = artifacts.require("WitnetProxy")
const WitnetUpgradableBase = artifacts.require("WitnetUpgradableBase")

module.exports = async function (_, network, [, from, reporter, curator]) {
  
  let addresses = await utils.readJsonFromFile("./migrations/addresses.json")

  const networkArtifacts = settings.getArtifacts(network)
  const networkSpecs = settings.getSpecs(network)

  // Settle the order in which (some of the) framework artifacts must be deployed first
  const framework = {
    core: merge(Object.keys(networkArtifacts.core), ["WitOracleRadonRegistry", "WitOracle"],),
    apps: merge(Object.keys(networkArtifacts.apps), [],),
  }

  // Settle WitOracle as first  dependency on all Wit/oracle appliances
  framework.apps.forEach(appliance => {
    networkSpecs[appliance].baseDeps = merge([], networkSpecs[appliance]?.baseDeps, ["WitOracle"])
  })

  // Settle network-specific initialization params, if any...
  networkSpecs.WitOracle.mutables = merge(networkSpecs.WitOracle?.mutables, {
    types: ["address[]"], values: [[reporter]],
  })
  networkSpecs.WitRandomness.mutables = merge(networkSpecs.WitRandomness?.mutables, {
    types: ["address"], values: [curator],
  })

  // Loop on framework domains ...
  const palette = [6, 4]
  for (const domain in framework) {
    const color = palette[Object.keys(framework).indexOf(domain)]

    let first = true
    // Loop on domain artifacts ...
    for (const index in framework[domain]) {
      const base = framework[domain][index]
      const impl = networkArtifacts[domain][base]

      if (impl.indexOf(base) < 0) {
        console.info(`Mismatching inheriting artifact names on settings/artifacts.js: ${base} <! ${impl}`)
        process.exit(1)
      }

      let targetBaseAddr = utils.getNetworkArtifactAddress(network, domain, addresses, base)
      if (
        domain !== "core" &&
        !selection.includes(base) && !selection.includes(impl) && !process.argv.includes(`--${domain}`) &&
        (utils.isNullAddress(targetBaseAddr) || (await web3.eth.getCode(targetBaseAddr)).length < 3)
      ) {
        // skip dapps that haven't yet been deployed, not have they been selected from command line
        continue
      } else {
        if (first) {
          console.info(`\n  \x1b[1;39;4${color}m`, domain.toUpperCase(), "ARTIFACTS", " ".repeat(106 - domain.length), "\x1b[0m")
          first = false
        }
      }

      const baseArtifact = artifacts.require(base)
      const implArtifact = artifacts.require(impl)

      const targetSpecs = await unfoldTargetSpecs(domain, impl, base, from, network, networkArtifacts, networkSpecs)
      let targetAddr = await determineTargetAddr(impl, targetSpecs, networkArtifacts)
      const targetCode = await web3.eth.getCode(targetAddr)

      if (targetSpecs.isUpgradable) {
        
        let proxyImplAddr;
        if (!utils.isNullAddress(targetBaseAddr) && (await web3.eth.getCode(targetBaseAddr)).length > 3) {
          // a proxy address with actual code is found in the addresses file...
          try {
            proxyImplAddr = await getProxyImplementation(targetSpecs.from, targetBaseAddr)    
            if (
              proxyImplAddr === targetAddr ||
              utils.isNullAddress(proxyImplAddr) || selection.includes(base) || process.argv.includes("--upgrade-all")
            ) {
              implArtifact.address = targetAddr
            
            } else {
              implArtifact.address = proxyImplAddr
            }
          } catch (ex) {
            console.info("Error: trying to upgrade from non-upgradable artifact?")
            console.info(ex)
            process.exit(1)
          }
        
        } else {
          // no proxy address in file or no code in it...
          targetBaseAddr = await deployCoreBase(targetSpecs, targetAddr)
          implArtifact.address = await deployTarget(network, target, targetSpecs, networkArtifacts)
          proxyImplAddr = implArtifact.address
          // settle new proxy address in file
          addresses = await settleArtifactAddress(addresses, network, domain, base, targetBaseAddr)
        }
        baseArtifact.address = targetBaseAddr

        // link implementation artifact to external libs so it can get eventually verified
        for (const index in targetSpecs?.baseLibs) {
          const libArtifact = artifacts.require(networkArtifacts.libs[targetSpecs.baseLibs[index]])
          implArtifact.link(libArtifact)
        };

        // determine whether a new implementation is available and prepared for upgrade, 
        // and whether an upgrade should be perform...
        const legacy = await implArtifact.at(proxyImplAddr)
        const legacyClass = await legacy.class.call({ from: targetSpecs.from })
        const legacyVersion = await legacy.version.call({ from: targetSpecs.from })
        
        let upgradeProxy = targetAddr !== proxyImplAddr;
        if (upgradeProxy && !selection.includes(base)) {  
          if (legacyClass == impl && legacyVersion.slice(0, 5) === version.slice(0, 5) && !utils.isDryRun(network)) {
            upgradeProxy = false;
            // targetAddr = proxyImplAddr;
          } else {
            upgradeProxy = process.argv.includes("--upgrade-all")
            // console.info(
            //   `\n   > Upgrade artifact to ` + `\x1b[1;39m${impl} v${version}\x1b[0m? (y/N) `
            // )
            // upgradeProxy = ["y", "yes"].includes(await utils.prompt(""))
          }
        }
        if (upgradeProxy) {
          if (targetCode.length < 3) {
            targetAddr = await deployTarget(network, impl, targetSpecs, networkArtifacts, legacyVersion)
          }
          utils.traceHeader(`Upgrading '${base}'...`)
          await upgradeCoreBase(baseArtifact.address, targetSpecs, targetAddr)
          implArtifact.address = targetAddr
        } else {
          utils.traceHeader(`Upgradable '${base}'`)
          if (selection.includes(base)) {
            console.info(`   > \x1b[90mSorry, nothing to upgrade.\x1b[0m`)
          }
          if (legacyVersion && legacyVersion.slice(0, 5) === version.slice(0, 5)) {
            if (legacyVersion.slice(-7) !== version.slice(-7)) {
              console.info(`   > \x1b[90mPlease, bump up package version before upgrading.\x1b[0m`)
            } 
          } else if (legacyVersion && legacyVersion.slice(-7) === version.slice(-7)) {
            console.info(`   > \x1b[90mPlease, commit your changes before upgrading.\x1b[0m`)
          }
        }
        if (implArtifact.address !== targetAddr && legacyVersion.slice(0, 5) === version.slice(0, 5)) {
          console.info("  ", `> contract address:   \x1b[9${color}m${baseArtifact.address} \x1b[0m`)
          console.info("  ",
            `                     \x1b[9${color}m -->\x1b[3${color}m`,
            implArtifact.address,
            "!==", `\x1b[30;43m${targetAddr}\x1b[0m`
          )
        } else {
          console.info("  ", `> contract address:  \x1b[9${color}m ${baseArtifact.address} -->\x1b[3${color}m`,
            implArtifact.address, "\x1b[0m"
          )
        }
      
      } else {
        if (targetCode.length < 3) {
          targetAddr = await deployTarget(network, impl, targetSpecs, networkArtifacts)
        }
        utils.traceHeader(`Immutable '${base}'`)
        if (
          selection.includes(impl) || utils.isNullAddress(targetBaseAddr) ||
          (await web3.eth.getCode(targetBaseAddr)).length < 3
        ) {
          baseArtifact.address = targetAddr
          implArtifact.address = targetAddr
          if (!utils.isNullAddress(targetBaseAddr) && targetBaseAddr !== targetAddr) {
            console.info("  ",
              `> contract address:  \x1b[3${color}m ${targetBaseAddr} \x1b[0m==>`,
              `\x1b[9${color}m${targetAddr}\x1b[0m`
            )
          } else {
            console.info("  ", `> contract address:  \x1b[9${color}m`, targetAddr, "\x1b[0m")
          }
        } else {
          baseArtifact.address = targetBaseAddr
          implArtifact.address = targetBaseAddr
          if (!utils.isNullAddress(targetBaseAddr) && targetBaseAddr !== targetAddr) {
            console.info("  ",
              `> contract address:  \x1b[9${color}m ${targetBaseAddr}\x1b[0m !==`,
              `\x1b[41m${targetAddr}\x1b[0m`
            )
          } else {
            console.info("  ", `> contract address:  \x1b[9${color}m ${targetAddr}\x1b[0m`)
          }
        }
        addresses = await saveAddresses(addresses, network, domain, base, baseArtifact.address)
      }
      const core = await implArtifact.at(baseArtifact.address)
      try {
        console.info("  ", "> contract curator:  \x1b[35m", await core.owner.call({ from }), "\x1b[0m")
      } catch {}
      console.info("  ", "> contract class:    \x1b[1;39m", await core.class.call({ from }), "\x1b[0m")
      try {
        const deployedVersion = await core.version.call({ from })
        if (deployedVersion.slice(0, 5) !== version.slice(0, 5)) {
          console.info("  ", "> contract version:  \x1b[1;39m", deployedVersion, "\x1b[0m!==", `\x1b[93m${version}\x1b[0m`)
        } else {
          console.info("  ", "> contract version:  \x1b[1;39m", deployedVersion, "\x1b[0m")
        }
      } catch {}
      console.info("  ", "> contract specs:    ", await core.specs.call({ from }), "\x1b[0m")
      console.info()
    }
  }
}
async function deployCoreBase (targetSpecs, targetAddr) {
  const deployer = await WitnetDeployer.deployed()
  const proxyInitArgs = targetSpecs.mutables
  const proxySalt = "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(targetSpecs.vanity), 32).toString("hex")
  const proxyAddr = await deployer.determineProxyAddr.call(proxySalt, { from: targetSpecs.from })
  if ((await web3.eth.getCode(proxyAddr)).length < 3) {
    // if no contract is yet deployed on the expected address
    // proxify to last deployed implementation, and initialize it:
    utils.traceHeader("Deploying new 'WitnetProxy'...")
    const initdata = proxyInitArgs ? web3.eth.abi.encodeParameters(proxyInitArgs.types, proxyInitArgs.values) : "0x"
    if (initdata.length > 2) {
      console.info("  ", "> initdata types:    \x1b[90m", proxyInitArgs.types, "\x1b[0m")
      utils.traceData("   > initdata values:    ", initdata.slice(2), 64, "\x1b[90m")
    }
    utils.traceTx(await deployer.proxify(proxySalt, targetAddr, initdata, { from: targetSpecs.from }))
  }
  if ((await web3.eth.getCode(proxyAddr)).length < 3) {
    console.info(`Error: WitnetProxy was not deployed on the expected address: ${proxyAddr}`)
    process.exit(1)
  }
  return proxyAddr
}

async function upgradeCoreBase (proxyAddr, targetSpecs, targetAddr) {
  const initdata = (targetSpecs.mutables?.types
    ? web3.eth.abi.encodeParameters(targetSpecs.mutables.types, targetSpecs.mutables.values)
    : "0x"
  )
  if (initdata.length > 2) {
    console.info("  ", "> initdata types:    \x1b[90m", targetSpecs.mutables.types, "\x1b[0m")
    utils.traceData("   > initdata values:    ", initdata.slice(2), 64, "\x1b[90m")
  }
  const proxy = await WitnetProxy.at(proxyAddr)
  utils.traceTx(await proxy.upgradeTo(targetAddr, initdata, { from: targetSpecs.from }))
  return proxyAddr
}

async function deployTarget (network, target, targetSpecs, networkArtifacts, legacyVersion) {
  const constructorArgs = await utils.readJsonFromFile("./migrations/constructorArgs.json")
  const deployer = await WitnetDeployer.deployed()
  const targetInitCode = encodeTargetInitCode(target, targetSpecs, networkArtifacts)
  const targetConstructorArgs = encodeTargetConstructorArgs(targetSpecs).slice(2)
  const targetSalt = "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(targetSpecs.vanity), 32).toString("hex")
  const targetAddr = await deployer.determineAddr.call(targetInitCode, targetSalt, { from: targetSpecs.from })
  utils.traceHeader(`Deploying '${target}'...`)
  if (legacyVersion && legacyVersion.slice(-7) === version.slice(-7)) {
    console.info(   `   > \x1b[41mWARNING:\x1b[0m           \x1b[31mLatest changes were not committed into Github!\x1b[0m`)
  }
  if (targetSpecs?.constructorArgs?.types.length > 0) {
    console.info("  ", "> constructor types: \x1b[90m", JSON.stringify(targetSpecs.constructorArgs.types), "\x1b[0m")
    utils.traceData("   > constructor values: ", targetConstructorArgs, 64, "\x1b[90m")
  }
  try {
    utils.traceTx(await deployer.deploy(targetInitCode, targetSalt, { from: targetSpecs.from }))
  } catch (ex) {
    console.info(`Error: cannot deploy artifact ${target} on counter-factual address ${targetAddr}:`)
    process.exit(1)
  }
  if ((await web3.eth.getCode(targetAddr)).length <= 3) {
    console.info(`Error: deployment of '${target}' into ${targetAddr} failed.`)
    process.exit(1)
  } else {
    if (!constructorArgs[network]) constructorArgs[network] = {}
    constructorArgs[network][target] = targetConstructorArgs
    await utils.overwriteJsonFile("./migrations/constructorArgs.json", constructorArgs)
  }
  return targetAddr
}

async function determineTargetAddr (target, targetSpecs, networkArtifacts) {
  const targetInitCode = encodeTargetInitCode(target, targetSpecs, networkArtifacts)
  const targetSalt = "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(targetSpecs.vanity), 32).toString("hex")
  return (await WitnetDeployer.deployed()).determineAddr.call(targetInitCode, targetSalt, { from: targetSpecs.from })
}

async function determineProxyAddr (from, nonce) {
  const salt = nonce ? "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(nonce), 32).toString("hex") : "0x0"
  const deployer = await WitnetDeployer.deployed()
  return await deployer.determineProxyAddr.call(salt, { from })
}

function encodeTargetConstructorArgs (targetSpecs) {
  return web3.eth.abi.encodeParameters(targetSpecs.constructorArgs.types, targetSpecs.constructorArgs.values)
}

function encodeTargetInitCode (target, targetSpecs, networkArtifacts) {
  // extract bytecode from target's artifact, replacing lib references to actual addresses
  const targetCodeUnlinked = artifacts.require(target).toJSON().bytecode
  if (targetCodeUnlinked.length < 3) {
    console.info(`Error: cannot deploy abstract arfifact ${target}.`)
    process.exit(1)
  }
  const targetCode = linkBaseLibs(
    targetCodeUnlinked,
    targetSpecs.baseLibs,
    networkArtifacts
  )
  if (targetCode.indexOf("__") > -1) {
    // console.info(targetCode)
    console.info(
      `Error: artifact ${target} depends on library`,
      targetCode.substring(targetCode.indexOf("__"), 42),
      "which is not known or has not been deployed."
    )
    process.exit(1)
  }
  const targetConstructorArgsEncoded = encodeTargetConstructorArgs(targetSpecs)
  return targetCode + targetConstructorArgsEncoded.slice(2)
}

async function getProxyImplementation (from, proxyAddr) {
  const proxy = await WitnetProxy.at(proxyAddr)
  return await proxy.implementation.call({ from })
}

function linkBaseLibs (bytecode, baseLibs, networkArtifacts) {
  if (baseLibs && Array.isArray(baseLibs)) {
    for (const index in baseLibs) {
      const base = baseLibs[index]
      const impl = networkArtifacts.libs[base]
      const lib = artifacts.require(impl)
      bytecode = bytecode.replaceAll(`__${impl}${"_".repeat(38 - impl.length)}`, lib.address.slice(2))
    }
  }
  return bytecode
}

async function saveAddresses(addresses, network, domain, base, addr) {
  if (!addresses[network]) addresses[network] = {}
  if (!addresses[network][domain]) addresses[network][domain] = {}
  addresses[network][domain][base] = addr
  await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
  return addresses
}

async function unfoldTargetSpecs (domain, target, targetBase, from, network, networkArtifacts, networkSpecs, ancestors) {
  if (!ancestors) ancestors = []
  else if (ancestors.includes(targetBase)) {
    console.info(`Core dependencies loop detected: '${targetBase}' in ${ancestors}`,)
    process.exit(1)
  }
  const specs = {
    baseDeps: [],
    baseLibs: [],
    from,
    mutables: { types: [], values: [] },
    immutables: { types: [], values: [] },
    intrinsics: { types: [], values: [] },
    isUpgradable: utils.isUpgradableArtifact(target),
    vanity: networkSpecs[targetBase]?.vanity || 0,
  }
  // Iterate inheritance tree from `base` to `impl` as to settle deployment specs
  target.split(/(?=[A-Z])/).reduce((split, part) => {
    split = split + part
    if (split.indexOf(targetBase) > -1) {
      specs.baseDeps = merge(specs.baseDeps, networkSpecs[split]?.baseDeps)
      specs.baseLibs = merge(specs.baseLibs, networkSpecs[split]?.baseLibs)
      if (networkSpecs[split]?.from && !utils.isDryRun(network)) {
        specs.from = networkSpecs[split].from
      }
      if (networkSpecs[split]?.vanity && !utils.isUpgradableArtifact(target)) {
        specs.vanity = networkSpecs[split].vanity
      }
      if (networkSpecs[split]?.immutables) {
        specs.immutables.types.push(...networkSpecs[split]?.immutables.types)
        specs.immutables.values.push(...networkSpecs[split]?.immutables.values)
      }
      if (networkSpecs[split]?.mutables) {
        specs.mutables.types.push(...networkSpecs[split]?.mutables.types)
        specs.mutables.values.push(...networkSpecs[split]?.mutables.values)
      }
    }
    return split
  })
  if (specs.baseDeps.length > 0) {
    // Iterate specs.baseDeps as to add deterministic addresses as first intrinsical constructor args
    specs.intrinsics.types.push(...new Array(specs.baseDeps.length).fill("address"))
    for (const index in specs.baseDeps) {
      const depsBase = specs.baseDeps[index]
      const depsImpl = networkArtifacts.core[depsBase]
      if (utils.isUpgradableArtifact(depsImpl)) {
        const depsVanity = networkSpecs[depsBase]?.vanity || Object.keys(networkArtifacts[domain]).indexOf(depsBase)
        const depsProxySalt = (depsVanity
          ? "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(depsVanity), 32).toString("hex")
          : "0x0"
        )
        specs.intrinsics.values.push(await determineProxyAddr(specs.from, depsProxySalt))
      } else {
        const depsImplSpecs = await unfoldTargetSpecs(
          domain, depsImpl, depsBase, specs.from, network, networkArtifacts, networkSpecs,
          [...ancestors, targetBase]
        )
        const depsImplAddr = await determineTargetAddr(depsImpl, depsImplSpecs, networkArtifacts)
        specs.intrinsics.values.push(depsImplAddr)
      }
    }
  }
  if (specs.isUpgradable) {
    // Add version tag to intrinsical constructor args if target artifact is expected to be upgradable
    specs.intrinsics.types.push("bytes32")
    specs.intrinsics.values.push(utils.fromAscii(version))
    if (target.indexOf("Trustable") < 0) {
      // Add _upgradable constructor args on non-trustable (ergo trustless) but yet upgradable targets
      specs.intrinsics.types.push("bool")
      specs.intrinsics.values.push(true)
    }
  }
  specs.constructorArgs = {
    types: specs?.immutables?.types || [],
    values: specs?.immutables?.values || [],
  }
  if (specs?.intrinsics) {
    specs.constructorArgs.types.push(...specs.intrinsics.types)
    specs.constructorArgs.values.push(...specs.intrinsics.values)
  }
  if (specs?.mutables && !specs.isUpgradable) {
    specs.constructorArgs.types.push(...specs.mutables.types)
    specs.constructorArgs.values.push(...specs.mutables.values)
  }
  return specs
}
