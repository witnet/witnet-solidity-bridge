const utils = require("../../../../src/utils")

const IWitnetOracleReporter = artifacts.require("IWitOracleReporter")
const WitOracle = artifacts.require("WitOracle")

module.exports = async function (_deployer, network, [,, from]) {
  const wrb = await WitOracle.deployed()
  const reporter = await IWitnetOracleReporter.at(wrb.address)
  if (!process.argv.includes("--queryIds")) {
    console.info("Usage: yarn ops:drp:pfs <ecosystem>:<chain> --queryIds <comma-separated-query-ids>")
    process.exit(0)
  }
  const queryIds = process.argv[process.argv.indexOf("--queryIds") + 1].split(",");
  console.info("> Network:      ", network)
  console.info("> WitOracle:    ", wrb.address)
  console.info("> Reporter:     ", from)
  for (const index in queryIds) {
    const queryId = queryIds[index]
    console.info("  ", "-".repeat(86))
    console.info("  ", "> Query id:          ", queryId)
    const queryStatus = await wrb.getQueryStatusTag(queryId)
    console.info("  ", "> Query status:      ", queryStatus)
    if (queryStatus === "Posted") {
      utils.traceTx(await reporter.methods['reportResult(uint256,bytes32,bytes)'](
        queryId, 
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "0xd8278118ef", // RadonErrors::BridgeGaveUp
        { from }
      ));
    }
  }
}
