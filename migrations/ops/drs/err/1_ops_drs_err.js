const addresses = require("../../../witnet.addresses")
const utils = require("../../../../scripts/utils")

const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")

module.exports = async function (_deployer, network, [,, reporter]) {
  const [realm, chain] = utils.getRealmNetworkFromString(network.split("-")[0])

  const wrb = await WitnetRequestBoard.at(addresses[realm][chain].WitnetRequestBoard)
  console.log("> WitnetRequestBoard address:", wrb.address)

  let queryId = parseInt(await wrb.getNextQueryId()) - 1
  process.argv.forEach((argv, index, args) => {
    if (argv === "--query") {
      queryId = args[index + 1]
    }
  })

  const query = await wrb.getQueryData(queryId)
  console.log(`Query #${queryId}:\n${query}`)
  if (
    query?.response.drTxHash === "0x0000000000000000000000000000000000000000000000000000000000000000"
  ) {
    console.log(`\n> Reporting failure onto query #${queryId}...`)
    const tx = await wrb.methods["reportResult(uint256,bytes32,bytes)"](
      queryId,
      "0x" + utils.padLeft("deadbeaf", "0, 64"),
      "0xd8278118E1",
      { from: reporter }
    )
    console.log(tx)
  } else {
    console.log(`\n> Query #${query} already reported:`)
    console.log(query)
  }
}
