var WBI = artifacts.require("WitnetBridgeInterface")
var BlockRelay = artifacts.require("BlockRelay")

module.exports = function (deployer, network) {
  console.log(`> Migrating WBI into ${network} network`)
  deployer.deploy(WBI, BlockRelay.address, 2, 3)
}
