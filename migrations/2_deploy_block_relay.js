var BlockRelay = artifacts.require("./BlockRelay.sol")

module.exports = function (deployer, network, accounts) {
  console.log("Network:", network)
  deployer.deploy(BlockRelay)
}
