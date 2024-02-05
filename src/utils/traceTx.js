const web3 = require("web3")

module.exports = function (tx) {
  console.info("  ", "> transaction hash: ", tx.receipt.transactionHash)
  console.info("  ", "> gas used:         ", tx.receipt.gasUsed.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ","))
  console.info("  ", "> gas price:        ", tx.receipt.effectiveGasPrice / 10 ** 9, "gwei")
  console.info("  ", "> total cost:       ", web3.utils.fromWei(BigInt(tx.receipt.gasUsed * tx.receipt.effectiveGasPrice).toString(), "ether"), "ETH")
}
