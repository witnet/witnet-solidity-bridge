const helpers = require("../helpers.cjs");
const { WitOracle } = require("../../../dist/src");
const { Witnet } = require("@witnet/sdk");

const { execSync } = require("node:child_process");
const prompt = require("inquirer").createPromptModule();

const deployables = helpers.readWitnetJsonFiles("modals", "requests", "templates");

module.exports = async (flags = {}, params = []) => {
	const [args] = helpers.deleteExtraFlags(params);

	const witOracle = await WitOracle.fromJsonRpcUrl(`http://127.0.0.1:${flags?.port || 8545}`, flags?.signer);

	const { force } = flags;
	const { network } = witOracle;

	if (!deployables.modals[network]) deployables.modals[network] = {};
	if (!deployables.requests[network]) deployables.requests[network] = {};
	if (!deployables.templates[network]) deployables.templates[network] = {};

	const registry = await witOracle.getWitOracleRadonRegistry();
	const deployer = await witOracle.getWitOracleRadonRequestFactory();

	if (!flags?.force) helpers.traceHeader(`${network.toUpperCase()}`, helpers.colors.lcyan);

	let assets = flags?.module ? require(`${flags.module}/assets`) : helpers.importRadonAssets(flags);
	if (!assets || Object.keys(assets).length === 0) {
		throw new Error("No Radon assets declared just yet in witnet/assets.");
	} else {
		assets = clearEmptyBranches(network, assets, args, !flags?.all);
	}

	const selection = (await selectWitnetArtifacts(registry, assets, args, "  ", !flags?.all)).sort(
		([a], [b]) => (a > b) - (a < b),
	);

	if (selection.length > 0) {
		for (const index in selection) {
			const [key, color, asset] = selection[index];

			if (asset instanceof Witnet.Radon.RadonModal) {
				if (flags?.deploy) {
					console.info();
					let user;
					if (!force) {
						user = await prompt([
							{
								message: `Deploy ${asset.constructor.name}::${color(key)} ?`,
								name: "continue",
								type: "confirm",
								default: true,
							},
						]);
					} else {
						console.info(color(key));
					}
					if (force || user?.continue) {
						let gasUsed = BigInt(0);
						const modal = await deployer
							.deployRadonRequestModal(asset, {
								confirmations: 1,
								onVerifyRadonRetrieval: (hash) => {
									process.stdout.write(`  > Verifying common data source => ${helpers.colors.gray(hash)} ... `);
								},
								onVerifyRadonRetrievalReceipt: (_hash, receipt) => {
									gasUsed += receipt?.gasUsed || BigInt(0);
									process.stdout.write(`${helpers.colors.lwhite("OK")}\n`);
								},
								onDeployRadonRequestModal: (address) => {
									process.stdout.write(
										`  > Replacing WitOracleRadonRequestModal => ${helpers.colors.mblue(address)} ... `,
									);
								},
								onDeployRadonRequestModalReceipt: (receipt) => {
									gasUsed += receipt?.gasUsed || BigInt(0);
									process.stdout.write(`${helpers.colors.lwhite("OK")}\n`);
								},
							})
							.catch((err) => {
								process.stdout.write(`${helpers.colors.mred("FAIL")}`);
								console.error(err);
								throw err;
							});
						if (gasUsed > 0) {
							process.stdout.write(`  > EVM cost: ${gasUsed} gas units.\n`);
						}
						deployables.modals[network][key] = modal.address;
						helpers.saveWitnetJsonFiles({ modals: deployables.modals });
					}
				}
				if (flags?.decode || flags["dry-run"]) {
					// todo: parse radon modal from evm contract
					if (deployables.modals[network]?.[key]) {
						console.info();
						// if deployed, decode deployed bytecode
						execSync(`npx witsdk radon decode ${key} --headline ${network.toUpperCase()}::${key}`, {
							stdio: "inherit",
							stdout: "inherit",
						});
					} else {
						// if not deployed, decode locally compiled bytecode
						execSync(`npx witsdk radon decode ${key}`, {
							stdio: "inherit",
							stdout: "inherit",
						});
					}
				}
			} else if (asset instanceof Witnet.Radon.RadonTemplate) {
				if (flags?.deploy) {
					console.info();
					let user;
					if (!force) {
						user = await prompt([
							{
								message: `Deploy ${asset.constructor.name}::${color(key)} ?`,
								name: "continue",
								type: "confirm",
								default: true,
							},
						]);
					} else {
						console.info(color(key));
					}
					if (force || user?.continue) {
						let target;
						let gasUsed = BigInt(0);
						const template = await deployer
							.deployRadonRequestTemplate(asset, {
								confirmations: 1,
								onVerifyRadonRetrieval: (hash) => {
									process.stdout.write(`  > Verifying parameterized data source => ${helpers.colors.gray(hash)} ... `);
								},
								onVerifyRadonRetrievalReceipt: (_hash, receipt) => {
									gasUsed += receipt?.gasUsed || BigInt(0);
									process.stdout.write(`${helpers.colors.lwhite("OK")}\n`);
								},
								onDeployRadonRequestTemplate: (address) => {
									target = address;
									process.stdout.write(
										`  > Replacing WitOracleRadonRequestTemplate => ${helpers.colors.mblue(address)} ... `,
									);
								},
								onDeployRadonRequestTemplateReceipt: (receipt) => {
									gasUsed += receipt?.gasUsed || BigInt(0);
									process.stdout.write(`${helpers.colors.lwhite("OK")}\n`);
								},
							})
							.catch((err) => {
								process.stdout.write(`${helpers.colors.mred("FAIL")}`);
								console.error(err);
								throw err;
							});
						// process.stdout.write(`  > WitOracleRadonRequestTemplate address: ${helpers.colors.mcyan(target)}\n`)
						deployables.templates[network][key] = template.address;
						helpers.saveWitnetJsonFiles({ templates: deployables.templates });

						const artifact = await witOracle.getWitOracleRadonRequestTemplateAt(target);
						for (const [sample, args] of Object.entries(asset?.samples)) {
							await artifact
								.verifyRadonRequest(args, {
									onVerifyRadonRequest: (radHash) => {
										process.stdout.write(`  > Verifying RAD hash for ${helpers.colors.lwhite(`${sample}`)} => `);
										process.stdout.write(`${helpers.colors.green(radHash)} ... `);
									},
									onVerifyRadonRequestReceipt: async (receipt) => {
										gasUsed += receipt?.gasUsed || BigInt(0);
										process.stdout.write(`${helpers.colors.lwhite("OK")}\n`);
									},
								})
								.catch((err) => {
									process.stdout.write(`${helpers.colors.mred("FAIL")}\n`);
									console.error(err);
								})
								.then((radHash) => {
									deployables.requests[network][`${key}$${sample}`] = radHash;
									helpers.saveWitnetJsonFiles({
										requests: deployables.requests,
									});
								});
						}
						if (gasUsed > 0) {
							process.stdout.write(`  > EVM cost: ${gasUsed} gas units.\n`);
						}
					}
				}
				if (flags?.decode || flags["dry-run"]) {
					if (deployables.templates[network]?.[key]) {
						// todo: parse radon template from evm contract
						console.info();
						// if deployed, decode deployed bytecode
						execSync(`npx witsdk radon decode ${key} --headline ${network.toUpperCase()}::${key}`, {
							stdio: "inherit",
							stdout: "inherit",
						});
					} else {
						// if not deployed, decode locally compiled bytecode
						execSync(`npx witsdk radon decode ${key}`, {
							stdio: "inherit",
							stdout: "inherit",
						});
					}
				}
			} else if (asset instanceof Witnet.Radon.RadonRequest) {
				if (flags?.deploy) {
					// && (!deployables.requests[network] || deployables.requests[network][key] !== asset.radHash)) {
					console.info();
					let user;
					if (!force) {
						user = await prompt([
							{
								message: `Formally verify RadonRequest::${color(key)} ?`,
								name: "continue",
								type: "confirm",
								default: true,
							},
						]);
					} else {
						console.info(helpers.colors.lwhite(`  ${key}`));
					}
					if (force || user?.continue) {
						let gasUsed = BigInt(0);
						const radHash = await registry
							.verifyRadonRequest(asset, {
								confirmations: 1,
								onVerifyRadonRetrieval: (hash) => {
									process.stdout.write(`  > Verifying new data source => ${helpers.colors.gray(hash)} ... `);
								},
								onVerifyRadonRetrievalReceipt: (_hash, receipt) => {
									gasUsed += receipt?.gasUsed || BigInt(0);
									process.stdout.write(helpers.colors.lwhite("OK\n"));
								},
								onVerifyRadonRequest: (hash) => {
									process.stdout.write(`  > Verifying new RAD hash    => ${helpers.colors.mgreen(hash)} ... `);
								},
								onVerifyRadonRequestReceipt: (receipt) => {
									gasUsed += receipt?.gasUsed || BigInt(0);
									process.stdout.write(helpers.colors.lwhite("OK\n"));
								},
							})
							.catch((err) => {
								process.stdout.write(helpers.colors.mred("FAIL"));
								console.error(err);
								throw err;
							});
						if (gasUsed > 0) {
							process.stdout.write(`  > EVM cost: ${gasUsed} gas units.\n`);
						} else {
							process.stdout.write(`  > RAD hash: ${helpers.colors.green(radHash)}\n`);
						}
						if (radHash) {
							deployables.requests[network][key] = radHash;
							helpers.saveWitnetJsonFiles({ requests: deployables.requests });
						}
					}
				}
				if (flags["dry-run"] || flags?.decode) {
					console.info();
					if (deployables.requests[network][key] !== undefined) {
						const bytecode = await registry.lookupRadonRequestBytecode(deployables.requests[network][key]);
						execSync(
							`npx witsdk radon ${flags["dry-run"] ? "dry-run --verbose" : "decode"} ${bytecode} --headline ${network.toUpperCase()}::${key}`,
							{ stdio: "inherit", stdout: "inherit" },
						);
					} else {
						execSync(`npx witsdk radon ${flags["dry-run"] ? "dry-run --verbose" : "decode"} ${key}`, {
							stdio: "inherit",
							stdout: "inherit",
						});
					}
				}
			}
		}
	}
};

function clearEmptyBranches(network, node, args, filter) {
	if (node) {
		const assets = Object.fromEntries(
			Object.entries(node)
				.map(([key, value]) => {
					if (
						(!filter ||
							args.find((arg) => key.toLowerCase().indexOf(arg.toLowerCase()) >= 0) ||
							deployables.modals[network][key] !== undefined ||
							deployables.requests[network][key] !== undefined ||
							deployables.templates[network][key] !== undefined) &&
						(value instanceof Witnet.Radon.RadonModal ||
							value instanceof Witnet.Radon.RadonTemplate ||
							value instanceof Witnet.Radon.RadonRequest)
					) {
						return [key, value];
					} else if (typeof value === "object") {
						if (countWitnetArtifacts(network, value, args, filter) > 0) {
							return [key, clearEmptyBranches(network, value, args, filter)];
						} else {
							return [key, undefined];
						}
					} else {
						return [key, undefined];
					}
				})
				.filter(([, value]) => value !== undefined),
		);
		if (Object.keys(assets).length > 0) {
			return assets;
		} else {
			return undefined;
		}
	}
}

function countWitnetArtifacts(network, assets, args, filter = false) {
	let counter = 0;
	Object.entries(assets).forEach(([key, value]) => {
		if (
			(value instanceof Witnet.Radon.RadonModal ||
				value instanceof Witnet.Radon.RadonRequest ||
				value instanceof Witnet.Radon.RadonTemplate ||
				value instanceof Witnet.Radon.RadonRetrieval) &&
			(!filter ||
				!args ||
				args.length === 0 ||
				args.find((arg) => key.toLowerCase().indexOf(arg.toLowerCase()) >= 0) ||
				deployables.modals[network][key] !== undefined ||
				deployables.requests[network][key] !== undefined ||
				deployables.templates[network][key] !== undefined)
		) {
			counter++;
		} else if (typeof value === "object") {
			counter += countWitnetArtifacts(network, value, args);
		}
	});
	return counter;
}

async function selectWitnetArtifacts(registry, assets = {}, args, indent = "", filter = false) {
	const network = registry.network;
	const selection = [];
	const prefix = `${indent}`;
	for (const index in Object.keys(assets)) {
		const key = Object.keys(assets)[index];
		const asset = assets[key];
		const isLast = parseInt(index, 10) === Object.keys(assets).length - 1;
		const found = args.find((arg) => key.toLowerCase().indexOf(arg.toLowerCase()) >= 0);
		let color = helpers.colors.white;
		if (asset instanceof Witnet.Radon.RadonRequest) {
			color = found
				? deployables.requests[network][key] !== undefined
					? helpers.colors.lcyan
					: helpers.colors.myellow
				: deployables.requests[network][key] !== undefined
					? helpers.colors.cyan
					: helpers.colors.gray;
			if (deployables.requests[network][key] !== undefined) {
				const radHash = asset.radHash;
				try {
					await registry.lookupRadonRequest(radHash);
					if (deployables.requests[network][key] !== radHash) {
						// already verified but with a different RAD hash
						color = found ? helpers.colors.mred : helpers.colors.red;
					}
				} catch {
					color = found ? helpers.colors.white : helpers.colors.gray;
				}
			}
			if (!filter || found || deployables.requests[network][key] !== undefined) {
				console.info(`${prefix}${color(key)}`);
				if (isLast) {
					console.info(`${prefix}`);
				}
			}
		} else if (asset instanceof Witnet.Radon.RadonTemplate || asset instanceof Witnet.Radon.RadonModal) {
			color = found
				? deployables.modals[network][key] !== undefined || deployables.templates[network][key] !== undefined
					? helpers.colors.lcyan
					: helpers.colors.myellow
				: deployables.modals[network][key] !== undefined || deployables.templates[network][key] !== undefined
					? helpers.colors.cyan
					: helpers.colors.gray;
			// todo: lookup whether radon template was already deployed on a different address ?
			if (
				!filter ||
				found ||
				deployables.modals[network][key] !== undefined ||
				deployables.templates[network][key] !== undefined
			) {
				console.info(`${prefix}${color(key)}`);
				if (isLast) {
					console.info(`${prefix}`);
				}
			}

			// } else if (asset instanceof Witnet.Radon.RadonRetrieval) {
			//     const argsCount = asset.argsCount
			//     if (!filter || found) {
			//         console.info(`${prefix}${color(key)} ${argsCount > 0 ? helpers.colors.green(`(${argsCount} args)`) : ""}`)
			//         if (isLast) {
			//             console.info(`${prefix}`)
			//         }
			//     }
		} else if (typeof asset === "object" && countWitnetArtifacts(network, asset, args, filter) > 0) {
			console.info(`${indent}${isLast ? "└─ " : "├─ "}${key}`);
			selection.push(
				...(await selectWitnetArtifacts(registry, asset, args, !isLast ? `${indent}│  ` : `${indent}   `, filter)),
			);
		}
		if (found) selection.push([key, color, asset]);
	}
	return selection;
}
