const { JsonRpcProvider } = require("ethers")
const { utils } = require("../../../dist/src")
const helpers = require("../helpers.cjs")

module.exports = async function (flags = {}, [ecosystem]) {
  if (ecosystem === undefined) {
    let provider
    try {
      provider = new JsonRpcProvider(`http://127.0.0.1:${flags?.port || 8545}`)
      const chainId = (await provider.getNetwork()).chainId
      ecosystem = utils.getEvmNetworkByChainId(chainId)
    } catch (err) {}
  }
  const networks = Object.fromEntries(
    Object.entries(helpers.supportedNetworks())
      .filter(([, config]) => {
        return (
          !flags ||
            (flags?.mainnets && config.mainnet) ||
            (flags?.testnets && !config.mainnet) ||
            (!flags?.mainnets && !flags?.testnets)
        )
      }).map(([network, config]) => [
        network, {
          browser: config?.verified,
          id: config?.network_id,
          mainnet: config?.mainnet,
          match: ecosystem && network.toLowerCase().indexOf(ecosystem.toLowerCase()) > -1,
          name: network,
          symbol: config?.symbol,
        },
      ])
  )
  helpers.traceTable(
    Object.values(networks).map(network => [
      network.match ? helpers.colors.mcyan(network.name) : helpers.colors.cyan(network.name),
      network.match ? helpers.colors.lwhite(network.symbol) : helpers.colors.white(network.symbol),
      network.match ? helpers.colors.myellow(helpers.commas(network.id)) : helpers.colors.yellow(helpers.commas(network.id)),
      network.match ? helpers.colors.white(network.browser || "") : helpers.colors.gray(network.browser || ""),
    ]), {
      headlines: [
        ":Network",
        ":Fee token",
        "Network Id",
        ":Verified Block Explorer",
      ],
    }
  )
  console.info(`^ Listed ${Object.keys(networks).length} networks.`)
}
