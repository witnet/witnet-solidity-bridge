module.exports = function (receipt, totalCost) {
  console.log("  ", "> block number:     ", receipt.blockNumber)
  console.log("  ", "> transaction hash: ", receipt.transactionHash)
  console.log("  ", "> transaction gas:  ", receipt.gasUsed)
  if (totalCost) {
    console.log("  ", "> total cost:       ", totalCost, "ETH")
  }
  console.log()
}