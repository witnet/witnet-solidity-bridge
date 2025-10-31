const ethUtils = require("ethereumjs-util")
const fs = require("fs")
const merge = require("lodash.merge")
const settings = require("../../settings/index").default
const utils = require("../utils").default
const version = `${
	require("../../../package").version
}-${require("child_process")
	.execSync("git log -1 --format=%h ../../../contracts")
	.toString()
	.trim()
	.substring(0, 7)}`

const selection = utils.getWitnetArtifactsFromArgs()
const WitnetProxy = artifacts.require("WitnetProxy")

let addresses, witnetDeployer

module.exports = async (
	_,
	network,
	[, , coreCurator, appsCurator, reporter],
) => {
	addresses = await utils.readJsonFromFile("./migrations/addresses.json")

	const networkArtifacts = settings.getArtifacts(network)
	const networkSpecs = settings.getSpecs(network)

	const WitnetDeployer = artifacts.require(networkArtifacts.WitnetDeployer)
	witnetDeployer = await WitnetDeployer.deployed()

	// Settle the order in which (some of the) framework artifacts must be deployed first
	const framework = {
		core: merge(Object.keys(networkArtifacts.core), [
			"WitOracleRadonRegistry",
			"WitOracle",
			"WitOracleRadonRequestFactoryModals",
			"WitOracleRadonRequestFactoryTemplates",
			"WitOracleRadonRequestFactory",
		]),
		apps: merge(Object.keys(networkArtifacts.apps), []),
	}

	// Settle WitOracle as first  dependency on all Wit/Oracle appliances
	framework.apps.forEach((appliance) => {
		if (!networkSpecs[appliance]) networkSpecs[appliance] = {}
		networkSpecs[appliance].baseDeps = merge(
			[],
			networkSpecs[appliance]?.baseDeps,
			["WitOracle"],
		)
	})

	// Settle network-specific initialization params, if any...
	networkSpecs.WitOracle.mutables = merge(networkSpecs.WitOracle?.mutables, {
		types: ["address[]"],
		values: [[reporter]],
	})
	networkSpecs.WitRandomness.mutables = merge(
		networkSpecs.WitRandomness?.mutables,
		{
			types: ["address"],
			values: [appsCurator],
		},
	)
	networkSpecs.WitPriceFeeds.mutables = merge(
		networkSpecs.WitPriceFeeds?.mutables,
		{
			types: ["address"],
			values: [appsCurator],
		},
	)

	// Loop on framework domains ...
	const palette = [6, 4]
	for (const domain in framework) {
		const from = domain === "core" ? coreCurator : appsCurator
		const color = palette[Object.keys(framework).indexOf(domain)]

		let first = true
		// Loop on domain artifacts ...
		for (const index in framework[domain]) {
			const base = framework[domain][index]
			const impl = networkArtifacts[domain][base]

			if (!impl) {
				panic(
					base,
					`No implementation artifact declared for "${base}" on settings/artifacts.js`,
				)
			}
			if (impl.indexOf(base) < 0) {
				panic(
					impl,
					`Mismatching inheritance on settings/artifacts.js: "${base}" <! "${impl}"`,
				)
			}
			// pasa si:
			//    - la base está seleccionada
			//    - ó, la implementación está seleccionada
			//    - ó, la implementación es no-actualizable
			//    - ó, la base tiene dirección grabada con código
			//    - ó, --<domain>` está especificado
			let targetBaseAddr = utils.getNetworkArtifactAddress(
				network,
				domain,
				addresses,
				base,
			)
			if (
				domain !== "core" &&
				!selection.includes(base) &&
				!selection.includes(impl) &&
				utils.isUpgradableArtifact(impl) &&
				(utils.isNullAddress(targetBaseAddr) ||
					(await web3.eth.getCode(targetBaseAddr)).length < 3) &&
				!process.argv.includes(`--${domain}`)
			) {
				// skip dapps that haven't yet been deployed, not have they been selected from command line
				continue
			} else {
				if (first) {
					console.info(
						`\n   \x1b[1;39;4${color}m`,
						domain.toUpperCase(),
						"ARTIFACTS",
						" ".repeat(101 - domain.length),
						"\x1b[0m",
					)
					first = false
				}
			}

			const baseArtifact = artifacts.require(base)
			const implArtifact = artifacts.require(impl)

			if (utils.isUpgradableArtifact(impl)) {
				if (
					process.argv.includes("--artifacts") &&
					process.argv.includes("--compile-none") &&
					!process.argv.includes("--upgrade-all") &&
					!selection.includes(base)
				) {
					utils.traceHeader(`Skipped '${base}'`)
					console.info("  ", `> contract address:   ${targetBaseAddr}`)
					continue
				}

				const targetSpecs = await unfoldTargetSpecs(
					domain,
					impl,
					base,
					from,
					network,
					networkArtifacts,
					networkSpecs,
				)
				const targetAddr = await determineTargetAddr(
					impl,
					targetSpecs,
					networkArtifacts,
				)
				const targetCode = await web3.eth.getCode(targetAddr)
				const targetVersion = getArtifactVersion(
					impl,
					targetSpecs.baseLibs,
					networkArtifacts,
				)

				let proxyImplAddr
				if (
					!utils.isNullAddress(targetBaseAddr) &&
					(await web3.eth.getCode(targetBaseAddr)).length > 3
				) {
					// a proxy address with actual code is found in the addresses file...
					try {
						proxyImplAddr = await getProxyImplementation(
							targetSpecs.from,
							targetBaseAddr,
						)
						if (
							proxyImplAddr === targetAddr ||
							utils.isNullAddress(proxyImplAddr) ||
							selection.includes(base) ||
							process.argv.includes("--upgrade-all")
						) {
							implArtifact.address = targetAddr
						} else {
							implArtifact.address = proxyImplAddr
						}
					} catch (ex) {
						panic(base, "Trying to upgrade non-upgradable artifact?", ex)
					}
				} else {
					// no proxy address in file or no code in it...
					implArtifact.address = await deployTarget(
						network,
						impl,
						targetSpecs,
						networkArtifacts,
					)
					if (implArtifact.address !== targetAddr) {
						throw new Error(
							`wrong proxy implementation address: ${implArtifact.address} != ${targetAddr}`,
						)
					}
					addresses = await settleArtifactAddress(
						addresses,
						network,
						domain,
						base,
						targetBaseAddr,
					)
					targetBaseAddr = await deployCoreBase(targetSpecs, targetAddr)
					proxyImplAddr = implArtifact.address
					if (addresses.default[domain][base] !== proxyImplAddr) {
						// settle new proxy address in file
						addresses = await settleArtifactAddress(
							addresses,
							network,
							domain,
							base,
							targetBaseAddr,
						)
					}
				}
				baseArtifact.address = targetBaseAddr

				// link implementation artifact to external libs so it can get eventually verified
				for (const index in targetSpecs?.baseLibs) {
					const libArtifact = artifacts.require(
						networkArtifacts.libs[targetSpecs.baseLibs[index]],
					)
					implArtifact.link(libArtifact)
				}

				// determine whether a new implementation is available and prepared for upgrade,
				// and whether an upgrade should be perform...
				const legacy = await implArtifact.at(proxyImplAddr)
				const legacyVersion = await legacy.version.call({
					from: targetSpecs.from,
				})

				let skipUpgrade = false
				let upgradeProxy =
					targetAddr !== proxyImplAddr &&
					versionCodehashOf(targetVersion) !== versionCodehashOf(legacyVersion)
				if (upgradeProxy && !utils.isDryRun(impl)) {
					if (
						!selection.includes(base) &&
						!process.argv.includes("--upgrade-all")
					) {
						if (
							versionLastCommitOf(targetVersion) ===
							versionLastCommitOf(legacyVersion)
						) {
							skipUpgrade = true
						}
						upgradeProxy = false
					}
				}
				if (upgradeProxy) {
					if (targetCode.length < 3) {
						await deployTarget(
							network,
							impl,
							targetSpecs,
							networkArtifacts,
							legacyVersion,
						)
					}
					utils.traceHeader(`Upgrading '${base}'...`)
					await upgradeCoreBase(baseArtifact.address, targetSpecs, targetAddr)
					implArtifact.address = targetAddr
					// settle new implementation address in addresses file
					addresses = await settleArtifactAddress(
						addresses,
						network,
						domain,
						impl,
						targetAddr,
					)
				} else {
					utils.traceHeader(`Upgradable '${base}'`)
				}
				if (
					!upgradeProxy &&
					targetVersion.slice(0, 4) !== legacyVersion.slice(0, 4)
				) {
					console.info("   > \x1b[30;43m MAJOR UPGRADE IS REQUIRED \x1b[0m")
				}
				if (
					targetAddr !== implArtifact.address &&
					versionTagOf(targetVersion) === versionTagOf(legacyVersion) &&
					versionCodehashOf(targetVersion) !== versionCodehashOf(legacyVersion)
				) {
					console.info(
						"  ",
						`> contract address:   \x1b[9${color}m${baseArtifact.address} \x1b[0m`,
					)
					console.info(
						"  ",
						`                     \x1b[9${color}m -->\x1b[3${color}m`,
						implArtifact.address,
						"!==",
						`\x1b[30;43m${targetAddr}\x1b[0m`,
					)
				} else {
					console.info(
						"  ",
						`> contract address:  \x1b[9${color}m ${baseArtifact.address} -->\x1b[3${color}m`,
						implArtifact.address,
						"\x1b[0m",
					)
				}
				await traceDeployedContractInfo(
					await implArtifact.at(baseArtifact.address),
					from,
					targetVersion,
				)
				if (!upgradeProxy) {
					if (skipUpgrade) {
						console.info(
							"   > \x1b[91mPlease, commit your changes before upgrading!\x1b[0m",
						)
					} else if (
						selection.includes(base) &&
						versionCodehashOf(targetVersion) ===
							versionCodehashOf(legacyVersion)
					) {
						console.info("   > \x1b[91mSorry, nothing to upgrade.\x1b[0m")
					} else if (
						versionLastCommitOf(targetVersion) !==
							versionLastCommitOf(legacyVersion) &&
						versionCodehashOf(targetVersion) !==
							versionCodehashOf(legacyVersion)
					) {
						if (
							targetVersion.slice(0, 4) === legacyVersion.slice(0, 4) ||
							process.argv.includes("--changelog")
						) {
							const changelog = require("child_process")
								.execSync(
									`git log ${versionLastCommitOf(
										legacyVersion,
									)}.. --date=short --color --format="%C(yellow)%cd %C(bold)%s%C(dim)" -- contracts/`,
								)
								.toString()
							const changes = changelog.split("\n").slice(0, -1)
							console.info(`   > contract changelog: ${changes[0]}\x1b[0m`)
							changes.slice(1).forEach((log) => {
								console.info(`                         ${log}\x1b[0m`)
							})
						}
						if (versionTagOf(targetVersion) === versionTagOf(legacyVersion)) {
							// both on same release tag
							console.info(
								"   > \x1b[90mPlease, consider bumping up the package version.\x1b[0m",
							)
						}
					}
				}
				console.info()
			} else {
				// create an array of implementations, including the one set up for current base,
				// but also all others in this network addresses file that share the same base
				// and have actual deployed code:
				const targets = [
					...utils.getNetworkBaseImplArtifactAddresses(
						network,
						domain,
						addresses,
						base,
					),
				]
				for (const ix in targets) {
					const target = targets[ix]

					if (
						process.argv.includes("--artifacts") &&
						process.argv.includes("--compile-none") &&
						!process.argv.includes("--upgrade-all") &&
						!selection.includes(target.impl)
					) {
						utils.traceHeader(`Skipped '${target.impl}'`)
						console.info("  ", `> contract address:  ${target.addr}`)
						continue
					}

					let targetAddr = target.addr
					target.specs = await unfoldTargetSpecs(
						domain,
						impl,
						base,
						from,
						network,
						networkArtifacts,
						networkSpecs,
					)

					if (target.impl === impl) {
						targetAddr = await determineTargetAddr(
							impl,
							target.specs,
							networkArtifacts,
						)
					}

					if (
						(domain === "core" || selection.includes(target.impl)) &&
						/* target.impl === impl || */ (utils.isNullAddress(target.addr) ||
							(await web3.eth.getCode(target.addr)).length < 3)
					) {
						if (
							target.impl !== impl ||
							fs.existsSync(`migrations/frosts/${domain}/${target.impl}.json`)
						) {
							if (
								!fs.existsSync(
									`migrations/frosts/${domain}/${target.impl}.json`,
								)
							) {
								utils.traceHeader(`Legacy '${target.impl}'`)
								console.info(
									"  ",
									`> \x1b[91mMissing migrations/frosts/${domain}/${target.impl}.json\x1b[0m`,
								)
								continue
							} else {
								fs.writeFileSync(
									`build/contracts/${target.impl}.json`,
									fs.readFileSync(
										`migrations/frosts/${domain}/${target.impl}.json`,
									),
									{ encoding: "utf8", flag: "w" },
								)
								target.addr = await defrostTarget(
									network,
									target.impl,
									target.specs,
									target.addr,
								)
							}
						} else {
							target.addr = await deployTarget(
								network,
								impl,
								target.specs,
								networkArtifacts,
							)
						}
						if (addresses.default[domain][impl] !== target.addr) {
							// settle immutable implementation address in addresses file
							addresses = await settleArtifactAddress(
								addresses,
								network,
								domain,
								impl,
								target.addr,
							)
						}
					} else if (
						utils.isNullAddress(target.addr) ||
						(await web3.eth.getCode(target.addr)).length < 3
					) {
						// skip targets for which no address or code is found
						continue
					}
					utils.traceHeader(
						`${impl === target.impl ? `Immutable '${base}'` : `Legacy '${target.impl}'`}`,
					)
					console.info(
						"  ",
						`> contract address:  \x1b[9${color}m`,
						target.addr,
						"\x1b[0m",
					)
					if (target.impl === impl) {
						baseArtifact.address = target.addr
						implArtifact.address = target.addr
					}
					await traceDeployedContractInfo(
						await baseArtifact.at(target.addr),
						from,
					)
					console.info()
				} // for targets
			} // !targetSpecs.isUpgradable
		} // for bases
	} // for domains
}

async function traceDeployedContractInfo(contract, from, targetVersion) {
	try {
		console.info(
			"  ",
			"> contract oracle:   \x1b[96m",
			await contract.witOracle.call({ from }),
			"\x1b[0m",
		)
	} catch {}
	try {
		console.info(
			"  ",
			"> contract curator:  \x1b[35m",
			await contract.owner.call({ from }),
			"\x1b[0m",
		)
	} catch {}
	console.info(
		"  ",
		"> contract class:    \x1b[1;39m",
		await contract.class.call({ from }),
		"\x1b[0m",
	)
	try {
		const deployedVersion = await contract.version.call({ from })
		// if (versionTagOf(deployedVersion) !== versionTagOf(getArtifactVersion(impl))) {
		// if (deployedVersion !== targetVersion) {
		if (
			targetVersion &&
			versionCodehashOf(deployedVersion) !== versionCodehashOf(targetVersion)
		) {
			console.info(
				"  ",
				`> contract version:   \x1b[1;39m${deployedVersion.slice(
					0,
					5,
				)}\x1b[0m${deployedVersion.slice(5)} !== \x1b[33m${
					targetVersion
				}\x1b[0m`,
			)
		} else {
			console.info(
				"  ",
				`> contract version:   \x1b[1;39m${deployedVersion.slice(0, 5)}\x1b[0m${deployedVersion.slice(5)}`,
			)
		}
		console.info(
			"  ",
			"> contract specs:    ",
			await contract.specs.call({ from }),
			"\x1b[0m",
		)
	} catch {}
}

async function deployCoreBase(targetSpecs, targetAddr) {
	const proxyInitArgs = targetSpecs.mutables
	const proxySalt =
		"0x" +
		ethUtils
			.setLengthLeft(ethUtils.toBuffer(targetSpecs.vanity), 32)
			.toString("hex")
	const proxyAddr = await witnetDeployer.determineProxyAddr.call(proxySalt, {
		from: targetSpecs.from,
	})
	if ((await web3.eth.getCode(proxyAddr)).length < 3) {
		// if no contract is yet deployed on the expected address
		// proxify to last deployed implementation, and initialize it:
		utils.traceHeader("Deploying new 'WitnetProxy'...")
		const initdata = proxyInitArgs
			? web3.eth.abi.encodeParameters(proxyInitArgs.types, proxyInitArgs.values)
			: "0x"
		if (initdata.length > 2) {
			console.info(
				"  ",
				"> initdata types:    \x1b[90m",
				JSON.stringify(proxyInitArgs.types),
				"\x1b[0m",
			)
			utils.traceData(
				"   > initdata values:    ",
				initdata.slice(2),
				64,
				"\x1b[90m",
			)
		}
		utils.traceTx(
			await witnetDeployer.proxify(proxySalt, targetAddr, initdata, {
				from: targetSpecs.from,
			}),
		)
	}
	if ((await web3.eth.getCode(proxyAddr)).length < 3) {
		console.info(
			`Error: WitnetProxy was not deployed on the expected address: ${proxyAddr}`,
		)
		process.exit(1)
	}
	return proxyAddr
}

async function upgradeCoreBase(proxyAddr, targetSpecs, targetAddr) {
	const initdata = targetSpecs.mutables?.types
		? web3.eth.abi.encodeParameters(
				targetSpecs.mutables.types,
				targetSpecs.mutables.values,
			)
		: "0x"
	if (initdata.length > 2) {
		console.info(
			"  ",
			"> initdata types:    \x1b[90m",
			JSON.stringify(targetSpecs.mutables.types),
			"\x1b[0m",
		)
		utils.traceData(
			"   > initdata values:    ",
			initdata.slice(2),
			64,
			"\x1b[90m",
		)
	}
	const proxy = await WitnetProxy.at(proxyAddr)
	utils.traceTx(
		await proxy.upgradeTo(targetAddr, initdata, { from: targetSpecs.from }),
	)
	return proxyAddr
}

async function defrostTarget(network, target, targetSpecs, targetAddr) {
	utils.traceHeader(`Defrosting '${target}'...`)
	const artifact = artifacts.require(target)
	const defrostCode = artifact.bytecode
	if (defrostCode.indexOf("__") > -1) {
		panic("Frosted libs not yet supported")
	}
	let constructorArgs = await utils.readJsonFromFile(
		"./migrations/constructorArgs.json",
	)
	constructorArgs = JSON.parse(
		constructorArgs[network][target] || constructorArgs.default[target] || {},
	)
	const defrostConstructorArgs = encodeTargetConstructorArgs(constructorArgs)
	const defrostInitCode = defrostCode + defrostConstructorArgs
	const defrostSalt =
		"0x" +
		ethUtils
			.setLengthLeft(ethUtils.toBuffer(targetSpecs.vanity), 32)
			.toString("hex")
	const defrostAddr = await witnetDeployer.determineAddr.call(
		defrostInitCode,
		defrostSalt,
		{ from: targetSpecs.from },
	)
	if (!utils.isNullAddress(targetAddr) && defrostAddr !== targetAddr) {
		panic(
			"Irreproducible address",
			`\x1b[91m${defrostAddr}\x1b[0m != \x1b[97m${targetAddr}\x1b[0m`,
		)
	} else {
		const metadata = JSON.parse(artifact.metadata)
		console.info("  ", "> compiler:          ", metadata.compiler.version)
		console.info(
			"  ",
			"> evm version:       ",
			metadata.settings.evmVersion.toUpperCase(),
		)
		console.info(
			"  ",
			"> optimizer:         ",
			JSON.stringify(metadata.settings.optimizer),
		)
		console.info(
			"  ",
			"> source code path:  ",
			metadata.settings.compilationTarget,
		)
		console.info(
			"  ",
			"> artifact codehash: ",
			web3.utils.soliditySha3(artifact.toJSON().deployedBytecode),
		)
	}
	try {
		utils.traceHeader(`Deploying '${target}'...`)
		if (defrostConstructorArgs.length > 0) {
			console.info(
				"  ",
				"> constructor types: \x1b[90m",
				JSON.stringify(targetSpecs.constructorArgs.types),
				"\x1b[0m",
			)
			utils.traceData(
				"   > constructor values: ",
				defrostConstructorArgs,
				64,
				"\x1b[90m",
			)
		}
		utils.traceTx(
			await witnetDeployer.deploy(defrostInitCode, defrostSalt, {
				from: targetSpecs.from,
			}),
		)
	} catch (ex) {
		panic("Deployment failed", null, ex)
	}
	return defrostAddr
}

async function deployTarget(
	network,
	target,
	targetSpecs,
	networkArtifacts,
	legacyVersion,
) {
	const constructorArgs = await utils.readJsonFromFile(
		"./migrations/constructorArgs.json",
	)
	const targetInitCode = encodeTargetInitCode(
		target,
		targetSpecs,
		networkArtifacts,
	)
	const targetConstructorArgs = encodeTargetConstructorArgs(
		targetSpecs.constructorArgs,
	)
	const targetSalt =
		"0x" +
		ethUtils
			.setLengthLeft(ethUtils.toBuffer(targetSpecs.vanity), 32)
			.toString("hex")
	const targetAddr = await witnetDeployer.determineAddr.call(
		targetInitCode,
		targetSalt,
		{ from: targetSpecs.from },
	)
	utils.traceHeader(`Deploying '${target}'...`)
	if (
		targetSpecs.isUpgradable &&
		versionLastCommitOf(legacyVersion) &&
		legacyVersion.slice(-7) === version.slice(-7)
	) {
		console.info(
			"   > \x1b[91mLatest changes were not previously committed into Github!\x1b[0m",
		)
	}
	if (targetSpecs?.baseLibs && Array.isArray(targetSpecs.baseLibs)) {
		for (const index in targetSpecs.baseLibs) {
			const libBase = targetSpecs.baseLibs[index]
			const libImpl = networkArtifacts.libs[libBase]
			console.info(
				"  ",
				`> external library:   \x1b[92m${libImpl}\x1b[0m @ \x1b[32m${artifacts.require(libImpl).address}\x1b[0m`,
			)
		}
	}
	if (targetSpecs?.constructorArgs?.types.length > 0) {
		console.info(
			"  ",
			"> constructor types: \x1b[90m",
			JSON.stringify(targetSpecs.constructorArgs.types),
			"\x1b[0m",
		)
		utils.traceData(
			"   > constructor values: ",
			targetConstructorArgs,
			64,
			"\x1b[90m",
		)
	}
	console.info("  ", `> tx signer address:  ${targetSpecs.from}`)
	console.info("  ", `> tx target address:  ${targetAddr}`)
	try {
		utils.traceTx(
			await witnetDeployer.deploy(targetInitCode, targetSalt, {
				from: targetSpecs.from,
			}),
		)
	} catch (ex) {
		panic("Deployment failed", `Expected address: ${targetAddr}`)
	}

	if (
		JSON.stringify(targetSpecs.constructorArgs) !==
		constructorArgs?.default[target]
	) {
		if (!constructorArgs[network]) constructorArgs[network] = {}
		constructorArgs[network][target] = JSON.stringify(
			targetSpecs.constructorArgs,
		) // targetConstructorArgs
		await utils.overwriteJsonFile(
			"./migrations/constructorArgs.json",
			constructorArgs,
		)
	}
	return targetAddr
}

function panic(header, body, exception) {
	console.info("  ", `> \x1b[97;41m ${header} \x1b[0m ${body}`)
	if (exception) console.info(exception)
	console.info()
	process.exit(0)
}

async function determineTargetAddr(target, targetSpecs, networkArtifacts) {
	const targetInitCode = encodeTargetInitCode(
		target,
		targetSpecs,
		networkArtifacts,
	)
	const targetSalt =
		"0x" +
		ethUtils
			.setLengthLeft(ethUtils.toBuffer(targetSpecs.vanity), 32)
			.toString("hex")
	return witnetDeployer.determineAddr.call(targetInitCode, targetSalt, {
		from: targetSpecs.from,
	})
}

async function determineProxyAddr(from, nonce) {
	const salt = nonce
		? "0x" +
			ethUtils.setLengthLeft(ethUtils.toBuffer(nonce), 32).toString("hex")
		: "0x0"
	return witnetDeployer.determineProxyAddr
		.call(salt, { from })
		.catch((err) => console.error(err))
}

function encodeTargetConstructorArgs(constructorArgs) {
	return constructorArgs?.types && constructorArgs?.values
		? web3.eth.abi
				.encodeParameters(constructorArgs.types, constructorArgs.values)
				.slice(2)
		: ""
}

function encodeTargetInitCode(target, targetSpecs, networkArtifacts) {
	// extract bytecode from target's artifact, replacing lib references to actual addresses
	const targetCodeUnlinked = artifacts.require(target).toJSON().bytecode
	if (targetCodeUnlinked.length < 3) {
		panic(target, "Abstract contract")
	}
	const targetCode = linkBaseLibs(
		targetCodeUnlinked,
		targetSpecs.baseLibs,
		networkArtifacts,
	)
	if (targetCode.indexOf("__") > -1) {
		panic(
			target,
			`Missing library: ${targetCode.substring(targetCode.indexOf("__"), 42)}`,
		)
	}
	const targetConstructorArgsEncoded = encodeTargetConstructorArgs(
		targetSpecs.constructorArgs,
	)
	return targetCode + targetConstructorArgsEncoded
}

async function getProxyImplementation(from, proxyAddr) {
	const proxy = await WitnetProxy.at(proxyAddr)
	return await proxy.implementation.call({ from })
}

function linkBaseLibs(bytecode, baseLibs, networkArtifacts) {
	if (baseLibs && Array.isArray(baseLibs)) {
		for (const index in baseLibs) {
			const base = baseLibs[index]
			const impl = networkArtifacts.libs[base]
			const lib = artifacts.require(impl)
			bytecode = bytecode.replaceAll(
				`__${impl}${"_".repeat(38 - impl.length)}`,
				lib.address.slice(2),
			)
		}
	}
	return bytecode
}

async function settleArtifactAddress(
	addresses,
	network,
	domain,
	artifact,
	addr,
) {
	if (!addresses[network]) addresses[network] = {}
	if (!addresses[network][domain]) addresses[network][domain] = {}
	addresses[network][domain][artifact] = addr
	await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
	return addresses
}

async function unfoldTargetSpecs(
	domain,
	target,
	targetBase,
	from,
	network,
	networkArtifacts,
	networkSpecs,
	ancestors,
) {
	if (!ancestors) ancestors = []
	else if (ancestors.includes(targetBase)) {
		panic(target, `Dependencies loop: "${targetBase}" in ${ancestors}`)
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
		specs.intrinsics.types.push(
			...new Array(specs.baseDeps.length).fill("address"),
		)
		for (const index in specs.baseDeps) {
			const depsBase = specs.baseDeps[index]
			const depsImpl =
				networkArtifacts.core[depsBase] || networkArtifacts.apps[depsBase]
			if (utils.isUpgradableArtifact(depsImpl)) {
				const depsVanity =
					networkSpecs[depsBase]?.vanity ||
					Object.keys(networkArtifacts[domain]).indexOf(depsBase)
				const depsProxySalt = depsVanity
					? "0x" +
						ethUtils
							.setLengthLeft(ethUtils.toBuffer(depsVanity), 32)
							.toString("hex")
					: "0x0"
				specs.intrinsics.values.push(
					await determineProxyAddr(specs.from, depsProxySalt),
				)
			} else {
				const depsImplSpecs = await unfoldTargetSpecs(
					domain,
					depsImpl,
					depsBase,
					specs.from,
					network,
					networkArtifacts,
					networkSpecs,
					[...ancestors, targetBase],
				)
				let depsImplAddr = utils.getNetworkArtifactAddress(
					network,
					domain,
					addresses,
					depsImpl,
				)
				if (
					utils.isNullAddress(depsImplAddr) ||
					(await web3.eth.getCode(depsImplAddr).length) < 3
				) {
					depsImplAddr = await determineTargetAddr(
						depsImpl,
						depsImplSpecs,
						networkArtifacts,
					)
				}
				specs.intrinsics.values.push(depsImplAddr)
			}
		}
	}
	if (specs.isUpgradable) {
		// Add version tag to intrinsical constructor args if target artifact is expected to be upgradable
		specs.intrinsics.types.push("bytes32")
		specs.intrinsics.values.push(
			"0x" +
				utils.padRight(
					utils.fromAscii(
						getArtifactVersion(target, specs.baseLibs, networkArtifacts),
					),
					"0",
					64,
				),
		)
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
	const bytecode = linkBaseLibs(
		artifacts.require(target).bytecode,
		targetBaseLibs,
		networkArtifacts,
	)
	return `${version}-${web3.utils.soliditySha3(bytecode).slice(2, 9)}`
}

function versionTagOf(version) {
	return version.slice(0, 5)
}
function versionLastCommitOf(version) {
	return version?.length >= 21 ? version.slice(-15, -8) : ""
}
function versionCodehashOf(version) {
	return version?.length >= 20 ? version.slice(-7) : ""
}
