const { Command } = require("commander");
require("dotenv").config({ quiet: true })

const cron = require("node-cron")
const moment = require("moment")
const program = new Command();
const promisePoller = require("promise-poller").default

const { ethers, utils, WitOracle } = require("../../../dist/src");
const { colors, traceHeader } = require("../helpers.cjs")

const commas = (number) => {
	const parts = number.toString().split(".")
	const result =
		parts.length <= 1
			? `${parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`
			: `${parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")}.${parts[1]}`
	return result
}

const CHECK_BALANCE_SECS = process.env.WITNET_SOLIDITY_RANDOMIZER_CHECK_BALANCE_SECS || 900
const CONFIRMATIONS = process.env.WITNET_SOLIDITY_RANDOMIZER_CONFIRMATIONS || 2
const POLLING_MSECS = process.env.WITNET_SOLIDITY_RANDOMIZER_POLLING_MSECS || 15000

main()

async function main() {
	
	program
		.name("npx --package @witnet/solidity randomizer")
		.description("Bot that pays for randomize requests in the specified network under the specified schedule.")

	program
		.option(
			"--chain <ecosystem:network>",
			"Make sure the randomizer bot connects to this EVM chain.",
			process.env.WITNET_SOLIDITY_RANDOMIZER_NETWORK || undefined,
		)
		.option(
			"--host <host>",
			"Host name or IP address where the signing ETH/RPC gateway is expected to be running.",
			(host) => host.replace(/\/$/, ""),
			process.env.WITNET_SOLIDITY_RANDOMIZER_GATEWAY_HOST || "http://127.0.0.1"
		)
		.option(
			"--max-gas-price <gwei>",
			"Max. EVM gas price to pay when trying to request a new randomize (in gwei units).",
			process.env.WITNET_SOLIDITY_RANDOMIZER_MAX_GAS_PRICE_GWEI || undefined
		)
		.option(
			"--min-balance <eth>",
			"Signer's min. balance required to start running (in gas token units).",
			process.env.WITNET_SOLIDITY_RANDOMIZER_MIN_BALANCE || 0.01
		)
		.option(
			"--patron <evm_addr>",
			"Signer address that will pay for every randomize request, other than the gateway's default.",
			process.env.WITNET_SOLIDITY_RANDOMIZER_SIGNER || undefined
		)
		.option(
			"--port <port>",
			"HTTP port where the signing ETH/RPC gateway is expected to be listening.",
			process.env.WITNET_SOLIDITY_RANDOMIZER_GATEWAY_PORT || 8545
		)
		.option(
			"--schedule <schedule>",
			"Randomizing schedule (see ).",
			process.env.WITNET_SOLIDITY_RANDOMIZER_SCHEDULE || 
				"0 9 * * 6" // Every Saturday, at 9.00 am 
		)
		.option(
			"--schedule-overlap <bool>",
			"Whether multiple randomize requests can concurr upon tight schedules.",
			process.env.WITNET_SOLIDITY_RANDOMIZER_SCHEDULE_OVERLAP || true
		)
		.option(
			"--schedule-timezone <timezone>",
			"Randomizing time sonze (see https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).",
			process.env.WITNET_SOLIDITY_RANDOMIZER_SCHEDULE_TIMEZONE || 
				"Europe/Madrid"
		)
		.requiredOption(
			"--target <evm_addr>",
			"Address of the WitRandomness contract to be randomized.",
			process.env.WITNET_SOLIDITY_RANDOMIZER_TARGET || undefined
		);

	program.parse();

	const {
		chain,
		host,
		maxGasPrice,
		minBalance,
		patron,
		port,
		schedule,
		scheduleOverlap,
		scheduleTimezone,
		target,
	} = program.opts();

	traceHeader(`@WITNET/SOLIDITY RANDOMIZER BOT v${require("../../../package.json").version}`, colors.white)
		
	console.info(`> ETH/RPC gateway:  ${host}:${port}`)

	const witOracle = patron
		? await WitOracle.fromJsonRpcUrl(`${host}:${port}`, patron)
		: await WitOracle.fromJsonRpcUrl(`${host}:${port}`)
	const { network, provider, signer } = witOracle

	if (chain && network !== chain) {
		throw new Error(
			`Fatal: connected to wrong network: ${network.toUpperCase()}`,
		)
	}

	console.info(`> ETH/RPC network:  ${network}`)

	const randomizer = await witOracle.getWitRandomnessAt(target)
	const artifact = await randomizer.getEvmImplClass()
	const symbol = utils.getEvmNetworkSymbol(network)
	const version = await randomizer.getEvmImplVersion()

	console.info(
		`> ${artifact}:${" ".repeat(Math.max(0, 16 - artifact.length))} ${target} [${version}]`,
	)

	let randomizeWaitBlocks
	if (artifact === "WitRandomnessV3") {
		const settings = await randomizer.getSettings()
		console.info(`> On-chain settings`, settings)
		randomizeWaitBlocks = settings.randomizeWaitBlocks
	}

	// check initial balance
	const balance = await checkBalance()
	if (Number(ethers.formatEther(balance)) < minBalance) {
		console.error(
			`> Fatal: insufficient balance: ${ethers.formatEther(balance)} < ${minBalance} ${symbol}`,
		)
		process.exit(1)
	}
	console.info(`> Signer address: ${signer.address}`)

	// max acceptable gas price
	if (maxGasPrice) {
		console.info(`> Max gas price:  ${commas(maxGasPrice)} gwei`)
	}

	// validate schedule plan
	if (!cron.validate(schedule)) {
		console.error(
			`> Fatal: invalid randomizing schedule: "${schedule}"`,
		)
		process.exit(1)
	} else {
		console.info(
			`> Randomizing schedule: "${schedule}" at ${scheduleTimezone}`,
		)
		cron.schedule(schedule, async () => randomize(), {
			noOverlap: !scheduleOverlap,
			timezone: scheduleTimezone,
		})
	}

	// check balance periodically
	console.info(
		`> Checking balance every ${CHECK_BALANCE_SECS || 900} seconds ...`,
	)
	setInterval(checkBalance, (CHECK_BALANCE_SECS || 900) * 1000)

	async function checkBalance() {
		return provider
			.getBalance(signer)
			.then((balance) => {
				if (Number(ethers.formatEther(balance)) < minBalance) {
					console.info(
						`> Low balance !!! ${ethers.formatEther(balance)} ${symbol} (${signer.address})`,
					)
				} else {
					console.info(
						`> Signer balance: ${ethers.formatEther(balance)} ${symbol}`,
					)
				}
				return balance
			})
			.catch((err) => {
				console.error(err)
			})
	}

	async function randomize() {
		_lastClock = Date.now()

		let isRandomized = false
		const feeData = await randomizer.provider.getFeeData()
		if (Number(feeData.gasPrice) / 10 ** 9 > maxGasPrice) {
			console.info(
				`> Postponing randomize as current network gas price is too high: ${commas(
					Number(feeData.gasPrice) / 10 ** 9,
				)} gwei > ${commas(maxGasPrice)} gwei`,
			)
			setTimeout(randomize, POLLING_MSECS)
			return
		} else {
			console.info(`> Randomizing new block ...`)
		}
		randomizer
			.randomize({
				evmConfirmations: CONFIRMATIONS || 2,
				evmGasPrice: feeData.gasPrice,
			})
			.then(async (receipt) => {
				console.info(`  - Block number:  ${commas(receipt.blockNumber)}`)
				console.info(`  - Block hash:    ${receipt.blockHash}`)
				console.info(`  - Transaction:   ${receipt.hash}`)
				console.info(
					`  - Tx. gas price: ${
						receipt.gasPrice < BigInt(10 ** 9)
							? Number(Number(receipt.gasPrice) / 10 ** 9).toFixed(9)
							: commas(Number(Number(receipt.gasPrice) / 10 ** 9).toFixed(1))
					} gwei`,
				)
				const tx = await receipt.getTransaction()
				console.info(
					`  - Tx. cost:      ${ethers.formatEther(receipt.gasPrice * receipt.gasUsed + tx.value)} ${symbol}`,
				)
				const logs = await provider.getLogs({
					address: randomizer.address,
					fromBlock: receipt.blockNumber,
					toBlock: receipt.blockNumber,
				})
				let randomizeBlock = Number(tx.blockNumber)
				if (logs?.[0]) {
					if (
						logs[0].topics[0] ===
						"0x8cb766b09215126141c41df86fd488fe4745f22f3c995c3ad9aaf4c07195b946"
					) {
						randomizeBlock = Number(logs[0].data.slice(0, 66))
					}
				}

				return promisePoller({
					interval: POLLING_MSECS,
					taskFn: () =>
						randomizer
							.isRandomized(randomizeBlock)
							.then(async (isRandomized) => ({
								isRandomized,
								blockNumber: await provider.getBlockNumber(),
								randomizeBlock,
							})),
					shouldContinue: (err, result) => {
						if (err) {
							console.info(err)
						} else if (result && !result?.isRandomized) {
							const { blockNumber, randomizeBlock } = result
							const plus = Number(blockNumber) - Number(tx.blockNumber)
							if (randomizeWaitBlocks && plus > randomizeWaitBlocks) {
								return false
							} else {
								console.info(
									`> Awaiting randomness for block ${commas(randomizeBlock)} ... T + ${commas(plus)}`,
								)
							}
						}
						return !result || !result.isRandomized
					},
				}).then(async (result) => {
					if (result.isRandomized) {
						isRandomized = true
						console.info(`> Randomized block ${commas(randomizeBlock)}:`)
						const trails =
							await randomizer.fetchRandomnessAfterProof(randomizeBlock)
						console.info(`  - Finality block:   ${commas(trails.finality)}`)
						console.info(`  - Witnet DRT hash:  ${trails.trail?.slice(2)}`)
						if (artifact === "WitRandomnessV3") {
							console.info(`  - Wit/Oracle UUID:  ${trails.uuid?.slice(2)}`)
							console.info(
								`  - Wit/Oracle RNG:   ${(await randomizer.fetchRandomnessAfter(receipt.blockNumber))?.slice(2)}`,
							)
						} else {
							console.info(`  - Witnet result:    ${trails.uuid?.slice(2)}`)
						}
						console.info(
							`  - Witnet timestamp: ${moment.unix(trails.timestamp)}`,
						)
					}
					return result
				})
			})
			.then((result) => {
				if (result.isRandomized) {
					console.info(
						`> Next randomizing schedule: "${schedule}" at ${scheduleTimezone}`,
					)
				} else {
					console.info(
						`> Randomizing block ${commas(result.randomizeBlock)} is taking too long !!!`,
					)
					// retry immediately a new randomize request
					setTimeout(randomize, 0)
				}
			})
			.catch((err) => {
				console.error(err)
				if (isRandomized) {
					console.info(
						`> Next randomizing schedule: "${schedule}" at ${scheduleTimezone}`,
					)
				} else {
					console.info(
						`> Retrying in ${Math.floor(POLLING_MSECS / 1000)} seconds before next randomize ...`,
					)
					// retry immediately a new randomize request
					setTimeout(randomize, POLLING_MSECS)
				}
			})
	}
}
