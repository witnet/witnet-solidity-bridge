const ethUtils = require("ethereumjs-util")
const fs = require("fs")
const merge = require("lodash.merge")
const settings = require("../../settings")
const utils = require("../../src/utils")
const version = `${
  require("../../package").version
}-${
  require("child_process").execSync("git log -1 --format=%h ../../contracts").toString().trim().substring(0, 7)
}`

const selection = utils.getWitnetArtifactsFromArgs()

const WitnetDeployer = artifacts.require("WitnetDeployer")
const WitnetProxy = artifacts.require("WitnetProxy")

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
    if (!networkSpecs[appliance]) networkSpecs[appliance] = {}
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
  const palette = [6, 4,]
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
      // pasa si:
      //    - la base está seleccionada
      //    - ó, la implementación está seleccionada
      //    - ó, la implementación es no-actualizable
      //    - ó, la base tiene dirección grabada con código
      //    - ó, --<domain>` está especificado
      let targetBaseAddr = utils.getNetworkArtifactAddress(network, domain, addresses, base)
      if (
        domain !== "core" && 
          !selection.includes(base) && !selection.includes(base) && utils.isUpgradableArtifact(impl) &&
          (utils.isNullAddress(targetBaseAddr) || (await web3.eth.getCode(targetBaseAddr)).length < 3) &&
          !process.argv.includes(`--${domain}`)
      ) {
        // skip dapps that haven't yet been deployed, not have they been selected from command line
        continue
      } else {
        if (first) {
          console.info(`\n   \x1b[1;39;4${color}m`, domain.toUpperCase(), "ARTIFACTS", " ".repeat(101 - domain.length), "\x1b[0m")
          first = false
        }
      }

      const baseArtifact = artifacts.require(base)
      const implArtifact = artifacts.require(impl)

      if (utils.isUpgradableArtifact(impl)) {

        const targetSpecs = await unfoldTargetSpecs(domain, impl, base, from, network, networkArtifacts, networkSpecs)
        const targetAddr = await determineTargetAddr(impl, targetSpecs, networkArtifacts)        
        const targetCode = await web3.eth.getCode(targetAddr)
        const targetVersion = getArtifactVersion(impl, targetSpecs.baseLibs, networkArtifacts)

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
        const legacyVersion = await legacy.version.call({ from: targetSpecs.from })
        
        let skipUpgrade = false, upgradeProxy = (
          targetAddr !== proxyImplAddr 
            && versionCodehashOf(targetVersion) !== versionCodehashOf(legacyVersion)
        );
        if (upgradeProxy && !utils.isDryRun(impl)) {
          if (!selection.includes(base) && !process.argv.includes("--upgrade-all")) {
            if (versionLastCommitOf(targetVersion) === versionLastCommitOf(legacyVersion)) {
              skipUpgrade = true;
            }
            upgradeProxy = false;
          }
        }
        if (upgradeProxy) {
          if (targetCode.length < 3) {
            await deployTarget(network, impl, targetSpecs, networkArtifacts, legacyVersion)
          }
          utils.traceHeader(`Upgrading '${base}'...`)
          await upgradeCoreBase(baseArtifact.address, targetSpecs, targetAddr)
          implArtifact.address = targetAddr
        
        } else {
          utils.traceHeader(`Upgradable '${base}'`)
          if (skipUpgrade) {
            console.info(`   > \x1b[91mPlease, commit your changes before upgrading!\x1b[0m`)  
          
          } else if (
            selection.includes(base)
            && versionCodehashOf(targetVersion) === versionCodehashOf(legacyVersion)
          ) {
            console.info(`   > \x1b[91mSorry, nothing to upgrade.\x1b[0m`)
          
          } else if (
            versionTagOf(targetVersion) === versionTagOf(legacyVersion) 
            && versionLastCommitOf(targetVersion) !== versionLastCommitOf(legacyVersion)
            && versionCodehashOf(targetVersion) !== versionCodehashOf(legacyVersion)
          ) {
            console.info(`   > \x1b[90mPlease, consider bumping up the package version.\x1b[0m`)
          }
        }
        if (
          targetAddr !== implArtifact.address 
          && versionTagOf(targetVersion) === versionTagOf(legacyVersion)
          && versionCodehashOf(targetVersion) !== versionCodehashOf(legacyVersion)
        ) {
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
        await traceDeployedContractInfo(await implArtifact.at(baseArtifact.address), from, targetVersion)
      
      } else {
        
        // create an array of implementations, including the one set up for current base,
        // but also all others in this network addresses file that share the same base 
        // and have actual deployed code:
        const targets = [
          ...utils.getNetworkBaseImplArtifactAddresses(network, domain, addresses, base) 
        ]
        for (const ix in targets) {
          const target = targets[ix]
          
          let targetAddr;
          if (target.impl === impl) {
            target.specs = await unfoldTargetSpecs(domain, impl, base, from, network, networkArtifacts, networkSpecs)
            targetAddr = await determineTargetAddr(impl, target.specs, networkArtifacts)
          }
          if (
            selection.includes(target.impl) &&
            (target.impl === impl || utils.isNullAddress(target.addr) || (await web3.eth.getCode(target.addr)).length < 3)
          ) {
            if (target.impl !== impl) {
              if (!fs.existsSync(`../frosts/${domain}/${target.impl}.json`)) {
                traceHeader(`Legacy '${target.impl}'`)
                console.info("  ", `> \x1b[91mMissing migrations/frosts/${domain}/${target.impl}.json\x1b[0m`)
                continue;
              } else {
                fs.writeFileSync(
                  `build/contracts/${target.impl}.json`,
                  fs.readFileSync(`migrations/frosts/${target.impl}.json`),
                  { encoding: "utf8", flag: "w" }
                )
                targetAddr = target.addr
                target.addr = await defrostTarget(network, target.impl, target.specs, target.addr)
              }
            } else {
              target.addr = await deployTarget(network, impl, target.specs, networkArtifacts)
            }            
            // settle immutable implementation address in addresses file
            addresses = await settleArtifactAddress(addresses, network, domain, impl, target.addr)
          } else if ((utils.isNullAddress(target.addr) || (await web3.eth.getCode(target.addr)).length < 3)) {
            // skip targets for which no address or code is found
            continue;
          }
          utils.traceHeader(`${impl === target.impl ? `Immutable '${base}'` : `Legacy '${target.impl}'`}`)
          if (target.impl !== impl || target.addr === targetAddr) {
            console.info("  ", 
              `> contract address:  \x1b[9${color}m`, target.addr, "\x1b[0m"
            )
          } else {
            console.info("  ",
              `> contract address:  \x1b[9${color}m ${target.addr}\x1b[0m !==`,
              `\x1b[41m${targetAddr}\x1b[0m`
            )
          }
          if (target.impl === impl) {
            baseArtifact.address = target.addr
            implArtifact.address = target.addr
          }
          await traceDeployedContractInfo(await baseArtifact.at(target.addr), from)
        } // for targets
      } // !targetSpecs.isUpgradable
    } // for bases
  } // for domains
}

async function traceDeployedContractInfo(contract, from, targetVersion) {
  try {
    console.info("  ", "> contract oracle:   \x1b[96m", await contract.witOracle.call({ from }), "\x1b[0m")
  } catch {}
  try {
    console.info("  ", "> contract curator:  \x1b[35m", await contract.owner.call({ from }), "\x1b[0m")
  } catch {}
  console.info("  ", "> contract class:    \x1b[1;39m", await contract.class.call({ from }), "\x1b[0m")
  try {
    const deployedVersion = await contract.version.call({ from })
    // if (versionTagOf(deployedVersion) !== versionTagOf(getArtifactVersion(impl))) {
    // if (deployedVersion !== targetVersion) {
    if (targetVersion && versionCodehashOf(deployedVersion) !== versionCodehashOf(targetVersion)) {
      console.info("  ", `> contract version:   \x1b[1;39m${deployedVersion.slice(0, 5)}\x1b[0m${deployedVersion.slice(5)} !== \x1b[93m${targetVersion}\x1b[0m`)
    } else {
      console.info("  ", `> contract version:   \x1b[1;39m${deployedVersion.slice(0, 5)}\x1b[0m${deployedVersion.slice(5)}`)
    }
  } catch {}
  console.info("  ", "> contract specs:    ", await contract.specs.call({ from }), "\x1b[0m")
  console.info()
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
      console.info("  ", "> initdata types:    \x1b[90m", JSON.stringify(proxyInitArgs.types), "\x1b[0m")
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
    console.info("  ", "> initdata types:    \x1b[90m", JSON.stringify(targetSpecs.mutables.types), "\x1b[0m")
    utils.traceData("   > initdata values:    ", initdata.slice(2), 64, "\x1b[90m")
  }
  const proxy = await WitnetProxy.at(proxyAddr)
  utils.traceTx(await proxy.upgradeTo(targetAddr, initdata, { from: targetSpecs.from }))
  return proxyAddr
}

async function defrostTarget (network, target, targetSpecs, targetAddr) {
  const deployer = WitnetDeployer.deployed()
  const artifact = artifacts.require(target)
  const defrostCode = artifact.bytecode
  if (defrostCode.indexOf("__") > -1) {
    console.info(`Cannot defrost '${target}: external libs not yet supported.`)
    process.exit(1)
  }
  const constructorArgs = await utils.readJsonFromFile("./migrations/constructorArgs.json")
  const defrostConstructorArgs = constructorArgs[network][target] || constructorArgs.default[target] || ""
  const defrostInitCode = targetCode + defrostConstructorArgs
  const defrostSalt = "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(targetSpecs.vanity), 32).toString("hex")
  const defrostAddr = await deployer.determineAddr.call(targetInitCode, targetSalt, { from: targetSpecs.from })
  if (defrostAddr !== targetAddr) {
    console.info(`Cannot defrost '${target}: irreproducible address: ${defrostAddr} != ${targetAddr}`)
    process.exit(1)
  } else {
    utils.traceHeader(`Defrosted ${target.impl}`)
    const metadata = JSON.parse(target.artifact.metadata)
    console.info("  ", "> compiler:          ", metadata.compiler.version)
    console.info("  ", "> evm version:       ", metadata.settings.evmVersion.toUpperCase())
    console.info("  ", "> optimizer:         ", JSON.stringify(metadata.settings.optimizer))
    console.info("  ", "> artifact codehash: ", web3.utils.soliditySha3(target.artifact.toJSON().deployedBytecode))
  }
  try {
    utils.traceHeader(`Deploying '${target}'...`)
    if (defrostConstructorArgs.length > 0) {
      console.info("  ", "> constructor types: \x1b[90m", JSON.stringify(targetSpecs.constructorArgs.types), "\x1b[0m")
      utils.traceData("   > constructor values: ", defrostConstructorArgs, 64, "\x1b[90m")  
    }
    utils.traceTx(await deployer.deploy(defrostInitCode, defrostSalt, { from: targetSpecs.from }))
  } catch (ex) {
    console.info(`Cannot defrost '${target}': deployment failed:`)
    console.log(ex)
    process.exit(1)
  }
  return defrostAddr
}

async function deployTarget (network, target, targetSpecs, networkArtifacts, legacyVersion) {
  const constructorArgs = await utils.readJsonFromFile("./migrations/constructorArgs.json")
  const deployer = await WitnetDeployer.deployed()
  const targetInitCode = encodeTargetInitCode(target, targetSpecs, networkArtifacts)
  const targetConstructorArgs = encodeTargetConstructorArgs(targetSpecs).slice(2)
  const targetSalt = "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(targetSpecs.vanity), 32).toString("hex")
  const targetAddr = await deployer.determineAddr.call(targetInitCode, targetSalt, { from: targetSpecs.from })
  utils.traceHeader(`Deploying '${target}'...`)
  if (targetSpecs.isUpgradable && versionLastCommitOf(legacyVersion) && legacyVersion.slice(-7) === version.slice(-7)) {
    console.info(   `   > \x1b[41mWARNING:\x1b[0m           \x1b[31mLatest changes were not committed into Github!\x1b[0m`)
  }
  if (targetSpecs?.baseLibs && Array.isArray(targetSpecs.baseLibs)) {
    for (const index in targetSpecs.baseLibs) {
      const libBase = targetSpecs.baseLibs[index]
      const libImpl = networkArtifacts.libs[libBase]
      console.info("  ", `> external library:   \x1b[92m${libImpl}\x1b[0m @ \x1b[32m${artifacts.require(libImpl).address}\x1b[0m`)
    }
  }
  if (targetSpecs?.constructorArgs?.types.length > 0) {
    console.info("  ", "> constructor types: \x1b[90m", JSON.stringify(targetSpecs.constructorArgs.types), "\x1b[0m")
    utils.traceData("   > constructor values: ", targetConstructorArgs, 64, "\x1b[90m")
  }
  try {
    utils.traceTx(await deployer.deploy(targetInitCode, targetSalt, { from: targetSpecs.from }))
  } catch (ex) {
    console.info(`Error: cannot deploy artifact ${target} on expected address ${targetAddr}:`)
    console.log(ex)
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

// async function saveAddresses(addresses, network, domain, base, addr) {
//   if (!addresses[network]) addresses[network] = {}
//   if (!addresses[network][domain]) addresses[network][domain] = {}
//   addresses[network][domain][base] = addr
//   await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
//   return addresses
// }

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
    specs.intrinsics.values.push(utils.fromAscii(getArtifactVersion(target, specs.baseLibs, networkArtifacts)))
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

function getArtifactVersion(target, targetBaseLibs, networkArtifacts) {
  const bytecode = linkBaseLibs(artifacts.require(target).bytecode, targetBaseLibs, networkArtifacts)
  return `${version}-${web3.utils.soliditySha3(bytecode).slice(2, 9)}`  
}

function versionTagOf(version) { return version.slice(0, 5) }
function versionLastCommitOf(version) { return version.length >= 13 ? version.slice(6, 13) : "" }
function versionCodehashOf(version) { return version.length >= 20 ? version.slice(-7) : "" }

