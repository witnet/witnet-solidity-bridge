var WBI = artifacts.require("./WitnetBridgeInterface.sol")
var BlockRelay = artifacts.require("./BlockRelay.sol")

module.exports = function (deployer, network, accounts) {
  console.log("Network:", network)
  deployer.deploy(WBI, BlockRelay.address)
}
