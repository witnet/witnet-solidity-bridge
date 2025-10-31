const helpers = require("../helpers.cjs")
const { WitOracle } = require("../../../dist/src")

module.exports = async (flags = {}) => {
	const witOracle = await WitOracle.fromJsonRpcUrl(
		`http://127.0.0.1:${flags?.port || 8545}`,
	)

	const { provider, network } = witOracle
	helpers.traceHeader(`${network.toUpperCase()}`, helpers.colors.lcyan)

	const signers = await provider.listAccounts()
	const records = []
	let totalEth = 0n
	records.push(
		...(await Promise.all(
			signers.map(async (signer) => {
				const eth = await provider.getBalance(signer.address)
				totalEth += eth
				return [signer.address, eth]
			}),
		)),
	)
	records.push(["", totalEth])

	helpers.traceTable(
		records.map(([address, eth], index) => {
			eth = Number(Number(eth) / 10 ** 18).toFixed(10)
			return [
				address !== "" ? index : "",
				address,
				address !== ""
					? helpers.colors.yellow(helpers.commas(eth))
					: helpers.colors.myellow(helpers.commas(eth)),
			]
		}),
		{
			headlines: [
				"INDEX",
				"EVM SIGNER ADDRESSES",
				`$${helpers.colors.lwhite("ETH")} BALANCE`,
			],
			humanizers: [helpers.commas, undefined],
			colors: [undefined, helpers.colors.mblue],
		},
	)
}
