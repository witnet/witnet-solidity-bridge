const helpers = require("../helpers.cjs");
const moment = require("moment");
const prompt = require("inquirer").createPromptModule();

const { Witnet } = require("@witnet/sdk");
const { utils, WitOracle } = require("../../../dist/src");

module.exports = async (options = {}, args = []) => {
	[args] = helpers.deleteExtraFlags(args);

	const witOracle = await WitOracle.fromEthRpcUrl(`http://127.0.0.1:${options?.port || 8545}`);

	const { network } = witOracle;
	helpers.traceHeader(`${network.toUpperCase()}`, helpers.colors.lcyan);

	let { target } = options;
	let chosen = false;
	if (!target) {
		const { apps } = utils.getEvmNetworkAddresses(network);
		const targets = Object.entries(apps || {})
			.filter(
				([key, address]) =>
					key.startsWith("WitPriceFeeds") &&
					key.indexOf("Upgradable") === -1 &&
					key.indexOf("Trustable") === -1 &&
					address !== "0x0000000000000000000000000000000000000000",
			)
			.map(([, address]) => address);
		if (targets.length === 1) {
			target = targets[0];
		} else {
			const selection = await prompt([
				{
					choices: targets,
					message: "Price feeds contract:",
					name: "target",
					type: "rawlist",
				},
			]);
			target = selection.target;
			chosen = true;
		}
	}

	// helper to transparently handle legacy price feed contracts
	// returns both the client and a flag indicating if the legacy implementation
	// was used (so we can avoid redundant RPC calls later).
	async function _resolvePriceFeeds(target) {
		try {
			return { client: await witOracle._getWitPriceFeeds(target), legacy: false };
		} catch (err) {
			console.warn(helpers.colors.yellow(`> Unable to initialize modern PriceFeeds (${err}), falling back to legacy`));
			return { client: await witOracle._getWitPriceFeedsLegacy(target), legacy: true };
		}
	}

	let { client: priceFeedClient, legacy: isLegacy } = await helpers
		.prompter(_resolvePriceFeeds(target))
		.catch((err) => {
			console.error(helpers.colors.mred(`Fatal: unable to initialize PriceFeeds wrapper: ${err.message || err}`));
			process.exit(0);
		});

	let artifact = await priceFeedClient.getEvmImplClass();
	// if the implementation class reports legacy but we already have a
	// modern client, switch over to the fully-baked legacy helper.
	if (artifact.includes("Legacy") && !isLegacy) {
		priceFeedClient = await helpers.prompter(witOracle._getWitPriceFeedsLegacy(target)).catch((err) => {
			console.error(
				helpers.colors.mred(`Fatal: unable to initialize legacy PriceFeeds wrapper: ${err.message || err}`),
			);
			process.exit(0);
		});
		artifact = await priceFeedClient.getEvmImplClass();
		isLegacy = true;
	}
	const version = await priceFeedClient.getEvmImplVersion();
	const maxWidth = Math.max(21, artifact.length + 2);
	console.info(
		`> ${helpers.colors.lwhite(artifact)}:${" ".repeat(
			maxWidth - artifact.length,
		)}${chosen ? "" : `${helpers.colors.lblue(target)} `}${helpers.colors.blue(`[ ${version} ]`)}`,
	);

	let priceFeeds = [];
	try {
		priceFeeds = (await priceFeedClient.lookupPriceFeeds()).sort((a, b) => a.symbol.localeCompare(b.symbol));
	} catch (err) {
		throw new Error(`Failed to lookup price feeds: ${err.message}`);
	}

	if (!options["trace-back"]) {
		const registry = await witOracle._getWitOracleRadonRegistry();
		priceFeeds = await helpers.prompter(
			Promise.all(
				priceFeeds.map(async (pf) => {
					let providers = [];
					if (pf?.oracle && pf.oracle.class === "Witnet") {
						const bytecode = await registry.lookupRadonRequestBytecode(pf.oracle.sources);
						const request = Witnet.Radon.RadonRequest.fromBytecode(bytecode);
						try {
							const dryrun = JSON.parse(await request.execDryRun({ verbose: true }));
							// const result = dryrun.tally.result
							providers = request.sources
								.map((source, index) => {
									let authority = source.authority.split(".").slice(-2)[0];
									authority = authority[0].toUpperCase() + authority.slice(1);
									return dryrun.retrieve[index].result?.RadonInteger
										? helpers.colors.mmagenta(authority)
										: helpers.colors.red(authority);
								})
								.sort((a, b) => helpers.colorstrip(a).localeCompare(helpers.colorstrip(b)));
						} catch (_err) {
							providers = request.sources
								.map((source) => {
									const authority = source.authority.split(".").slice(-2)[0];
									return helpers.colors.magenta(authority[0].toUpperCase() + authority.slice(1));
								})
								.sort((a, b) => helpers.colorstrip(a).localeCompare(helpers.colorstrip(b)));
						}
					} else if (pf?.oracle) {
						providers = [
							helpers.colors.mblue(
								`${pf.oracle.class}:${
									pf.oracle.sources !== "0x0000000000000000000000000000000000000000000000000000000000000000"
										? `${pf.oracle.target}:${pf.oracle.sources.slice(2, 10)}`
										: pf.oracle.target
								}`,
							),
						];
					} else if (pf?.mapper) {
						providers = pf.mapper.deps.map((dep) => helpers.colors.gray(dep.split(".").pop().toLowerCase()));
					}
					return {
						...pf,
						providers,
					};
				}),
			).catch((err) => console.error(err)),
		);
	}

	if (priceFeeds?.length > 0) {
		helpers.traceTable(
			priceFeeds.map((pf) => [
				pf.id4,
				pf.symbol,
				pf.lastUpdate.timestamp ? pf.lastUpdate.price.toFixed(6) : "",
				pf.lastUpdate.timestamp ? moment.unix(Number(pf.lastUpdate.timestamp)).fromNow() : "",
				...(options["trace-back"]
					? [
							pf.lastUpdate.trail !== "0x0000000000000000000000000000000000000000000000000000000000000000"
								? helpers.colors.mmagenta(pf.lastUpdate.trail.slice(2))
								: "",
						]
					: [pf?.providers?.join(" ")]),
			]),
			{
				colors: [helpers.colors.lwhite, helpers.colors.mgreen, helpers.colors.mcyan, helpers.colors.yellow, undefined],
				headlines: [
					":ID4",
					":CAPTION",
					"LAST PRICE:",
					"FRESHNESS:",
					options["trace-back"]
						? `DATA WITNESSING TRAIL ON ${helpers.colors.lwhite(`WITNET ${utils.isEvmNetworkMainnet(network) ? "MAINNET" : "TESTNET"}`)}`
						: ":DATA PROVIDERS",
				],
			},
		);
	} else {
		console.info(helpers.colors.yellow("^ No price feeds are currently supported."));
	}
};
