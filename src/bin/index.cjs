#!/usr/bin/env node

const dotenv = require("dotenv")
dotenv.config({ quiet: true })

const { JsonRpcProvider } = require("ethers")

const helpers = require("./helpers.cjs")
const { DEFAULT_LIMIT, DEFAULT_SINCE } = helpers
const { green, yellow, lwhite } = helpers.colors

const { utils } = require("../../dist/src/index.js")

/// CONSTANTS AND GLOBALS =============================================================================================

const settings = {
	flags: {
		all: "List all available Radon assets, even if not yet deployed.",
		apps: "Show addresses of Wit/Oracle appliances.",
		await: "Hold down until next event is triggered.",
		"check-result-status":
			"Check result status for each oracle query (supersedes --trace-back).",
		clone:
			"Clone the WitRandomness contract to a new instance (curated by --signer)",
		debug: "Outputs stack trace in case of error.",
		decode: "Decode selected Radon assets, as currently deployed.",
		deploy: "Deploy selected Radon assets, if not yet deployed.",
		"dry-run":
			"Dry-run selected Radon asset, as currently deployed (supersedes --decode).",
		force: "Force operations without user intervention.",
		help: "Describe how to use some command.",
		legacy: "Filter to those declared in witnet/assets folder.",
		parse: "Parse reported CBOR bytes",
		mainnets: "List supported EVM mainnets.",
		modals: "List deployed WitOracleRadonRequestModal contracts.",
		randomize: "Pay for a new randomize request.",
		requests: "Includes WitOracleRequest artifacts.",
		templates: "List deployed WitOracleRadonRequestTemplate contracts.",
		testnets: "List supported EVM testnets.",
		"trace-back": "Trace matching witnessing acts on Witnet.",
		verbose: "Outputs detailed information.",
		version: "Print binary name and version as headline.",
		voids: "Include deleted queries.",
	},
	options: {
		confirmations: {
			hint: "Number of block confirmations to wait for after an EVM transaction gets mined.",
			param: "NUMBER",
		},
		contract: {
			hint: "Path or name of the new mockup contract to be created",
			param: "path/to/output",
		},
		"filter-consumer": {
			hint: "Filter events triggered by given consumer.",
			param: "EVM_ADDRESS",
		},
		"filter-requester": {
			hint: "Filter events triggered by given requester.",
			param: "EVM_ADDRESS",
		},
		"filter-radHash": {
			hint: "Filter events referring the fragment of some RAD hash.",
			param: "FRAGMENT",
		},
		gasPrice: {
			hint: "EVM gas price to pay for.",
			param: "GAS_PRICE",
		},
		gasLimit: {
			hint: "Maximum EVM gas to spend per transaction.",
			param: "GAS_LIMIT",
		},
		into: {
			hint: "Address of some WitOracleConsumer contract where to report into.",
			param: "EVM_ADDRESS",
		},
		limit: {
			hint: `Limit number of listed records (default: ${DEFAULT_LIMIT}).`,
			param: "LIMIT",
		},
		module: {
			hint: "Package where to fetch Radon assets from (supersedes --legacy).",
			param: "NPM_PACKAGE",
		},
		network: {
			hint: "Bind mockup contract to immutable Wit/Oracle addresses on this EVM network.",
			param: "NETWORK",
		},
		offset: {
			hint: "Skip first records before listing (default: 0)",
			param: "OFFSET",
		},
		port: {
			hint: "Port on which the local ETH/RPC signing gateway is expected to be listening (default: 8545).",
			param: "HTTP_PORT",
		},
		push: {
			hint: "Retrieve the finalized result to the given Wit/Oracle query, and push it into some consumer contract (requires: --into).",
			param: "WIT_DR_TX_HASH",
		},
		remote: {
			hint: "Force the local gateway to rely on this remote ETH/RPC provider.",
			param: "PROVIDER_URL",
		},
		signer: {
			hint: "EVM signer address, other than gateway's default.",
			param: "EVM_ADDRESS",
		},
		since: {
			hint: `Process events since given EVM block number (default: ${DEFAULT_SINCE}).`,
			param: "EVM_BLOCK",
		},
		target: {
			hint: "Address of the contract to interact with.",
			param: "EVM_ADDRESS",
		},
	},
	envars: {
		ETHRPC_PRIVATE_KEYS:
			"=> Private keys used by the ETH/RPC gateway for signing EVM transactions.",
		ETHRPC_PROVIDER_URL:
			"=> Remote ETH/RPC provider to rely on, if no otherwise specified.",
		WITNET_KERMIT_PROVIDER_URL:
			"=> Wit/Kermit API-REST provider to connect to, if no otherwise specified.",
	},
}

/// MAIN WORKFLOW =====================================================================================================

main()

async function main() {
	let ethRpcPort = 8545
	if (process.argv.indexOf("--port") >= 0) {
		ethRpcPort = parseInt(process.argv[process.argv.indexOf("--port") + 1], 10)
	}
	let ethRpcProvider, ethRpcNetwork
	try {
		ethRpcProvider = new JsonRpcProvider(`http://127.0.0.1:${ethRpcPort}`)
		const network = await ethRpcProvider.getNetwork()
		const chainId = Number(network.chainId)
		ethRpcNetwork = utils.getEvmNetworkByChainId(chainId)
	} catch (_err) {}

	const router = {
		...(ethRpcNetwork
			? {
					accounts: {
						hint: `Show EVM gas currency balance for all available accounts on ${helpers.colors.mcyan(ethRpcNetwork.toUpperCase())}.`,
					},
					assets: {
						hint: `Formally verify deployable Radon assets into ${helpers.colors.mcyan(ethRpcNetwork.toUpperCase())}.`,
						params: "[RADON_ASSETS ...]",
						flags: ["all", "decode", "deploy", "dry-run", "force", "legacy"],
						options: ["module", "port", "signer"],
					},
					framework: {
						hint: `List available Wit/Oracle Framework addresses in ${helpers.colors.mcyan(ethRpcNetwork.toUpperCase())}.`,
						params: "[NAME_SUFFIX ...]",
						flags: ["modals", "templates", "verbose"],
						options: ["port"],
					},
					priceFeeds: {
						hint: `Show latest Wit/PriceFeeds updates on ${helpers.colors.mcyan(ethRpcNetwork.toUpperCase())}.`,
						params: "[EVM_ADDRESS]",
						flags: ["trace-back"],
					},
					queries: {
						hint: `Show latest Wit/Oracle queries pulled from smart contracts in ${helpers.colors.mcyan(ethRpcNetwork.toUpperCase())}.`,
						params: "[IDS ...]",
						flags: ["trace-back", "voids"],
						options: [
							"filter-radHash",
							"filter-requester",
							"limit",
							"offset",
							"since",
						],
					},
					randomness: {
						hint: `Show latest Wit/Randomness seeds randomized from ${helpers.colors.mcyan(ethRpcNetwork.toUpperCase())}.`,
						params: "[EVM_ADDRESS]",
						flags: ["clone", "randomize", "trace-back"],
						options: ["limit", "offset", "since", "gasPrice", "signer"],
						envars: [],
					},
					reports: {
						hint: `Show latest Wit/Oracle data reports pushed into ${helpers.colors.mcyan(ethRpcNetwork.toUpperCase())}.`,
						flags: ["parse", "trace-back"],
						options: [
							"filter-consumer",
							"filter-radHash",
							"limit",
							"offset",
							"since",
							"push",
							"into",
							"gasPrice",
							"gasLimit",
							"signer",
						],
					},
				}
			: {}),
		gateway: {
			hint: "Launch a local ETH/RPC signing gateway connected to some specific EVM network.",
			params: ["EVM_NETWORK"],
			options: ["port", "remote"],
			envars: ["ETHRPC_PRIVATE_KEYS", "ETHRPC_PROVIDER_URL"],
		},
		networks: {
			hint: "List EVM networks currently bridged to the Witnet blockchain.",
			params: "[EVM_ECOSYSTEM]",
			flags: ["mainnets", "testnets"],
		},
		// wizard: {
		//   hint: "Generate Solidity mockup contracts adapted to your use case.",
		//   options: [
		//     "contract",
		//     "network",
		//   ],
		// },
		commands: {
			accounts: require("./cli/accounts.cjs"),
			assets: require("./cli/assets.cjs"),
			framework: require("./cli/framework.cjs"),
			gateway: require("./cli/gateway.cjs"),
			networks: require("./cli/networks.cjs"),
			priceFeeds: require("./cli/priceFeeds.cjs"),
			queries: require("./cli/queries.cjs"),
			randomness: require("./cli/randomness.cjs"),
			reports: require("./cli/reports.cjs"),
			// wizard: require("./cli/wizard.cjs"),
		},
	}

	let [args, flags] = helpers.extractFlagsFromArgs(
		process.argv.slice(2),
		Object.keys(settings.flags),
	)
	if (flags.version) {
		showVersion()
	}
	let options
	;[args, options] = helpers.extractOptionsFromArgs(
		args,
		Object.keys(settings.options),
	)
	if (args[0] && router.commands[args[0]] && router[args[0]]) {
		const cmd = args[0]
		if (flags.help) {
			showCommandUsage(router, cmd, router[cmd])
		} else {
			try {
				await router.commands[cmd](
					{ ...settings, ...flags, ...options },
					args.slice(1),
				)
			} catch (e) {
				showUsageError(router, cmd, router[cmd], e, flags)
			}
		}
	} else {
		showMainUsage(router)
	}
}

function showMainUsage(router) {
	showUsageHeadline(router)
	showUsageFlags(["help", "debug", "version"])
	showUsageOptions(["port"])
	console.info("\nCOMMANDS:")
	const maxLength = Object.keys(router.commands)
		.map((key) => key.length)
		.reduce((prev, curr) => (curr > prev ? curr : prev))
	Object.keys(router.commands).forEach((cmd) => {
		if (router[cmd])
			console.info(
				"  ",
				`${cmd}${" ".repeat(maxLength - cmd.length)}`,
				" ",
				router[cmd]?.hint,
			)
	})
}

function showCommandUsage(router, cmd, specs) {
	showUsageHeadline(router, cmd, specs)
	showUsageFlags(specs?.flags || [])
	showUsageOptions(specs?.options || [])
	showUsageEnvars(specs?.envars || [])
}

function showUsageEnvars(envars) {
	if (envars.length > 0) {
		console.info("\nENVARS:")
		const maxWidth = envars
			.map((envar) => envar.length)
			.reduce((curr, prev) => (curr > prev ? curr : prev))
		envars.forEach((envar) => {
			if (envar.toUpperCase().indexOf("KEY") < 0 && process.env[envar]) {
				console.info(
					"  ",
					`${yellow(envar.toUpperCase())}${" ".repeat(maxWidth - envar.length)}`,
					` => Settled to "${process.env[envar]}"`,
				)
			} else {
				console.info(
					"  ",
					`${yellow(envar.toUpperCase())}${" ".repeat(maxWidth - envar.length)}`,
					` ${settings.envars[envar]}`,
				)
			}
		})
	}
}

function showUsageError(router, cmd, specs, error, flags) {
	showCommandUsage(router, cmd, specs)
	if (error) {
		console.info()
		if (flags?.debug) {
			console.error(error)
		} else {
			console.error(error?.stack?.split("\n")[0] || error)
		}
	}
}

function showUsageFlags(flags) {
	if (flags.length > 0) {
		const maxWidth = flags
			.map((flag) => flag.length)
			.reduce((curr, prev) => (curr > prev ? curr : prev))
		console.info("\nFLAGS:")
		flags.forEach((flag) => {
			if (settings.flags[flag]) {
				console.info(
					`   --${flag}${" ".repeat(maxWidth - flag.length)}   ${settings.flags[flag]}`,
				)
			}
		})
	}
}

function showUsageHeadline(router, cmd, specs) {
	console.info("USAGE:")
	const flags =
		cmd && (!specs?.flags || specs.flags.length === 0) ? "" : "[FLAGS] "
	const options = specs?.options && specs.options.length > 0 ? "[OPTIONS] " : ""
	if (cmd) {
		let params
		if (specs?.params) {
			const optionalize = (str) =>
				str.endsWith(" ...]")
					? `[<${str.slice(1, -5)}> ...]`
					: str[0] === "["
						? `[<${str.slice(1, -1)}>]`
						: `<${str}>`
			if (Array.isArray(specs?.params)) {
				params = `${specs.params.map((param) => optionalize(param)).join(" ")} `
			} else {
				params = `${optionalize(specs?.params)} `
			}
			console.info(
				`   ${lwhite(`npx witeth ${cmd}`)} ${params ? green(params) : ""}${flags}${options}`,
			)
		} else {
			console.info(`   ${lwhite(`npx witeth ${cmd}`)} ${flags}${options}`)
		}
		console.info("\nDESCRIPTION:")
		console.info(`   ${router[cmd].hint}`)
	} else {
		console.info(`   ${lwhite("npx witeth")} <COMMAND> ${flags}${options}`)
	}
}

function showUsageOptions(options) {
	if (options.length > 0) {
		console.info("\nOPTIONS:")
		const maxLength = options
			.map((option) =>
				settings.options[option].param
					? settings.options[option].param.length + option.length + 3
					: option.length,
			)
			.reduce((prev, curr) => (curr > prev ? curr : prev))
		options.forEach((option) => {
			if (settings.options[option].hint) {
				const str = `${option}${settings.options[option].param ? helpers.colors.gray(` <${settings.options[option].param}>`) : ""}`
				console.info(
					"  ",
					`--${str}${" ".repeat(maxLength - helpers.colorstrip(str).length)}`,
					"  ",
					settings.options[option].hint,
				)
			}
		})
	}
}

function showVersion() {
	console.info(
		`${lwhite(`Wit/Oracle Solidity CLI v${require("../../package.json").version}`)}`,
	)
}
