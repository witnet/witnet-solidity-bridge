const { JsonRpcProvider } = require("ethers");
const { utils } = require("../../../dist/src");
const helpers = require("../helpers.cjs");

module.exports = async (flags = {}, [ecosystem]) => {
	if (ecosystem === undefined) {
		let provider;
		try {
			provider = new JsonRpcProvider(`http://127.0.0.1:${flags?.port || 8545}`);
			const chainId = (await provider.getNetwork()).chainId;
			ecosystem = utils.getEvmNetworkByChainId(chainId);
		} catch (_err) {}
	}

	const networks = Object.values(
		Object.fromEntries(
			Object.entries(utils.getEvmNetworks())
				.filter(([, config]) => {
					return (
						!flags ||
						(flags?.mainnets && config.mainnet) ||
						(flags?.testnets && !config.mainnet) ||
						(!flags?.mainnets && !flags?.testnets)
					);
				})
				.map(([network, config]) => [
					network,
					{
						explorerUrl: config?.explorerUrl,
						id: config?.chainId,
						mainnet: config?.mainnet,
						match: ecosystem && network.toLowerCase().indexOf(ecosystem.toLowerCase()) > -1,
						name: config.name || network,
						symbol: config?.symbol,
						pushOnly: config?.pushOnly || false,
						addresses: config?.addresses || {},
					},
				]),
		),
	);
	
	if (networks.length > 0) {
		helpers.traceTable(
			networks.map((network) => [
				network.name,
				network.symbol,
				network.id,
				network.pushOnly ? "PUSH ONLY" : "PUSH & PULL",
				network.explorerUrl,
			]),
			{
				headlines: [":Network", ":Fee Token", "Network Id", ":Oracle Model", ":Verified Block Explorer"],
				colors: [
					helpers.colors.mcyan,
					helpers.colors.lwhite,
					helpers.colors.myellow,
					helpers.colors.lmagenta,
					helpers.colors.white,
				],
			},
		);
		console.info(`^ Listed ${Object.keys(networks).length} networks.`);
	} else {
		console.info("^ No networks found with the given filters.");
	}
};
