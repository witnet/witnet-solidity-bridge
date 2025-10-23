const { Witnet } = require("@witnet/sdk")
const moment = require("moment")
const prompt = require("inquirer").createPromptModule()
const { utils, WitOracle } = require("../../../dist/src/lib")
const helpers = require("../helpers.cjs")

module.exports = async function (options = {}, args = []) {
  [args] = helpers.deleteExtraFlags(args)

  const witOracle = await WitOracle.fromJsonRpcUrl(
    `http://127.0.0.1:${options?.port || 8545}`,
    options?.signer,
  )

  const { network, provider } = witOracle
  helpers.traceHeader(`${network.toUpperCase()}`, helpers.colors.lcyan)
  const framework = await helpers.prompter(utils.fetchWitOracleFramework(provider))

  let target = args[0]
  let chosen = false
  if (!target) {
    const artifacts = Object.entries(framework).filter(([key]) => key.startsWith("WitPriceFeeds"))
    if (artifacts.length === 1) {
      target = artifacts[0][1].address
    } else {
      const selection = await prompt([{
        choices: artifacts.map(([, artifact]) => artifact.address),
        message: "Price feeds contract:",
        name: "target",
        type: "rawlist",
      }])
      target = selection.target
      chosen = true
    }
  }

  let pfs
  try {
    pfs = await witOracle.getWitPriceFeedsAt(target)
  } catch {
    pfs = await witOracle.getWitPriceFeedsLegacyAt(target)
  }
  const artifact = await pfs.getEvmImplClass()
  if (artifact.indexOf("Legacy") >= 0) {
    pfs = await witOracle.getWitPriceFeedsLegacyAt(target)
  }
  const version = await pfs.getEvmImplVersion()
  const maxWidth = Math.max(21, artifact.length + 2)
  console.info(
    `> ${
      helpers.colors.lwhite(artifact)
    }:${
      " ".repeat(maxWidth - artifact.length)
    }${
      chosen ? "" : helpers.colors.lblue(target) + " "
    }${
      helpers.colors.blue(`[ ${version} ]`)
    }`
  )

  let priceFeeds = (await pfs.lookupPriceFeeds()).sort((a, b) => a.symbol.localeCompare(b.symbol))

  if (!options["trace-back"]) {
    const registry = await witOracle.getWitOracleRadonRegistry()
    priceFeeds = await helpers.prompter(
      Promise.all(
        priceFeeds.map(async pf => {
          let providers = []
          if (pf?.oracle && pf.oracle.class === "Witnet") {
            const bytecode = await registry.lookupRadonRequestBytecode(pf.oracle.sources)
            const request = Witnet.Radon.RadonRequest.fromBytecode(bytecode)
            try {
              const dryrun = JSON.parse(await request.execDryRun(true))
              // const result = dryrun.tally.result
              providers = request.sources.map((source, index) => {
                let authority = source.authority.split(".").slice(-2)[0]
                authority = authority[0].toUpperCase() + authority.slice(1)
                return (
                  dryrun.retrieve[index].result?.RadonInteger
                    ? helpers.colors.mmagenta(authority)
                    : helpers.colors.red(authority)
                )
              }).sort((a, b) => helpers.colorstrip(a).localeCompare(helpers.colorstrip(b)))
            } catch (err) {
              providers = request.sources.map(source => {
                const authority = source.authority.split(".").slice(-2)[0]
                return helpers.colors.magenta(authority[0].toUpperCase() + authority.slice(1))
              }).sort((a, b) => helpers.colorstrip(a).localeCompare(helpers.colorstrip(b)))
            }
          } else if (pf?.oracle) {
            providers = [helpers.colors.mblue(`${pf.oracle.class}:${
              pf.oracle.sources !== "0x0000000000000000000000000000000000000000000000000000000000000000"
                ? `${pf.oracle.target}:${pf.oracle.sources.slice(2, 10)}`
                : pf.oracle.target
            }`)]
          } else if (pf?.mapper) {
            providers = pf.mapper.deps.map(dep => helpers.colors.gray(dep.split(".").pop().toLowerCase()))
          }
          return {
            ...pf,
            providers,
          }
        })
      ).catch(err => console.error(err))
    )
  }

  if (priceFeeds?.length > 0) {
    helpers.traceTable(
      priceFeeds.map(pf => [
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
          : [
            pf?.providers && pf.providers.join(" "),
          ]),
      ]),
      {
        colors: [
          helpers.colors.lwhite,
          helpers.colors.mgreen,
          helpers.colors.mcyan,
          helpers.colors.yellow,,
        ],
        headlines: [
          ":ID4",
          ":CAPTION",
          "LAST PRICE:",
          "FRESHNESS:",
          options["trace-back"]
            ? `DATA WITNESSING TRAIL ON ${helpers.colors.lwhite(`WITNET ${utils.isEvmNetworkMainnet(network) ? "MAINNET" : "TESTNET"}`)}`
            : ":DATA PROVIDERS",
        ],
      }
    )
  } else {
    console.info("> No price feeds currently supported.")
  }
}
