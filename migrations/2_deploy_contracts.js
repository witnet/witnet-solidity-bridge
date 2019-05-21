var WBI = artifacts.require("./WitnetBridgeInterface.sol")

module.exports = function (deployer, network, accounts) {
  console.log("Network:", network)
  deployer.deploy(WBI)
}
