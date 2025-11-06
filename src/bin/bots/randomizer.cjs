const cron = require("node-cron")
require("dotenv").config({ quiet: true })
const moment = require("moment")
const promisePoller = require("promise-poller").default

const { ethers, utils, WitOracle } = require("../../../dist/src")

const commas = (number) => {
	const parts = number.toString().split(".")
	const result =
		parts.length <= 1
			? `${parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`
			: `${parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")}.${parts[1]}`
	return result
}

const CHECK_BALANCE_SECS = process.env.RANDOMIZER_CHECK_BALANCE_SECS
const CONFIRMATIONS = process.env.RANDOMIZER_CONFIRMATIONS || 2
const MAX_GAS_PRICE_GWEI = process.env.RANDOMIZER_MAX_GAS_PRICE_GWEI
const MIN_BALANCE = process.env.RANDOMIZER_MIN_BALANCE || 0
const NODE_CRON_OVERLAP = process.env.RANDOMIZER_CRON_OVERLAP || true
const NODE_CRON_SCHEDULE = process.env.RANDOMIZER_CRON_SCHEDULE || "0 0 9 * * 6" // default: every Saturday at 9.00 am
const NODE_CRON_TIMEZONE =
	process.env.RANDOMIZER_CRON_TIMEZONE || "Europe/Madrid" // see: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
const NETWORK =
	_spliceFromArgs(process.argv, `--network`) || process.env.RANDOMIZER_NETWORK
const POLLING_MSECS = process.env.RANDOMIZER_POLLING_MSECS || 15000
const GATEWAY_HOST = (
	_spliceFromArgs(process.argv, `--host`) ||
	process.env.RANDOMIZER_GATEWAY_HOST ||
	"http://127.0.0.1"
).replace(/\/$/, "")
const GATEWAY_PORT =
	_parseIntFromArgs(process.argv, `--port`) ||
	process.env.RANDOMIZER_GATEWAY_PORT
const SIGNER =
	_spliceFromArgs(process.argv, `--signer`) || process.env.RANDOMIZER_SIGNER
const TARGET =
	_spliceFromArgs(process.argv, `--target`) ||
	process.env.RANDOMIZER_TARGET ||
	undefined

main()

async function main() {
	const headline = `@WITNET/SOLIDITY RANDOMIZER v${require("../../../package.json").version}`
	console.info("=".repeat(120))
	console.info(headline)

	if (!GATEWAY_PORT) throw new Error(`Fatal: no PORT was specified.`)
	else if (!TARGET) throw new Error(`Fatal: no TARGET was specified.`)

	console.info(`> Ethereum gateway: ${GATEWAY_HOST}:${GATEWAY_PORT}`)

	const witOracle = SIGNER
		? await WitOracle.fromJsonRpcUrl(`${GATEWAY_HOST}:${GATEWAY_PORT}`, SIGNER)
		: await WitOracle.fromJsonRpcUrl(`${GATEWAY_HOST}:${GATEWAY_PORT}`)
	const { network, provider, signer } = witOracle

	if (NETWORK && network !== NETWORK) {
		throw new Error(
			`Fatal: connected to wrong network: ${network.toUpperCase()}`,
		)
	}

	console.info(`> Ethereum network: ${network}`)

	const randomizer = await witOracle.getWitRandomnessAt(TARGET)
	const artifact = await randomizer.getEvmImplClass()
	const symbol = utils.getEvmNetworkSymbol(network)
	const version = await randomizer.getEvmImplVersion()

	console.info(
		`> ${artifact}:${" ".repeat(Math.max(0, 16 - artifact.length))} ${TARGET} [${version}]`,
	)

	let randomizeWaitBlocks
	if (artifact === "WitRandomnessV3") {
		const settings = await randomizer.getSettings()
		console.info(`> On-chain settings`, settings)
		randomizeWaitBlocks = settings.randomizeWaitBlocks
	}

	// set start clock
	let _lastClock = Date.now()

	// check initial balance
	const balance = await checkBalance()
	if (Number(ethers.formatEther(balance)) < MIN_BALANCE) {
		console.error(
			`> Fatal: insufficient balance: ${ethers.formatEther(balance)} < ${MIN_BALANCE} ${symbol}`,
		)
		process.exit(1)
	}
	console.info(`> Signer address: ${signer.address}`)

	// max acceptable gas price
	if (MAX_GAS_PRICE_GWEI) {
		console.info(`> Max gas price:  ${commas(MAX_GAS_PRICE_GWEI)} gwei`)
	}

	// validate schedule plan
	if (!cron.validate(NODE_CRON_SCHEDULE)) {
		console.error(
			`> Fatal: invalid randomizing schedule: "${NODE_CRON_SCHEDULE}"`,
		)
		process.exit(1)
	} else {
		console.info(
			`> Randomizing schedule: "${NODE_CRON_SCHEDULE}" at ${NODE_CRON_TIMEZONE}`,
		)
		cron.schedule(NODE_CRON_SCHEDULE, async () => randomize(), {
			noOverlap: !NODE_CRON_OVERLAP,
			timezone: NODE_CRON_TIMEZONE,
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
				if (Number(ethers.formatEther(balance)) < MIN_BALANCE) {
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
		if (Number(feeData.gasPrice) / 10 ** 9 > MAX_GAS_PRICE_GWEI) {
			console.info(
				`> Postponing randomize as current network gas price is too high: ${commas(
					Number(feeData.gasPrice) / 10 ** 9,
				)} gwei > ${commas(MAX_GAS_PRICE_GWEI)} gwei`,
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
						`> Next randomizing schedule: "${NODE_CRON_SCHEDULE}" at ${NODE_CRON_TIMEZONE}`,
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
						`> Next randomizing schedule: "${NODE_CRON_SCHEDULE}" at ${NODE_CRON_TIMEZONE}`,
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

function _parseIntFromArgs(args, flag) {
	const argIndex = args.indexOf(flag)
	if (argIndex >= 0 && args.length > argIndex + 1) {
		const value = parseInt(args[argIndex + 1], 10)
		args.splice(argIndex, 2)
		return value
	}
}

function _spliceFromArgs(args, flag) {
	const argIndex = args.indexOf(flag)
	if (argIndex >= 0 && args.length > argIndex + 1) {
		const value = args[argIndex + 1]
		args.splice(argIndex, 2)
		return value
	}
}
