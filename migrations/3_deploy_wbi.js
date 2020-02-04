var WBI = artifacts.require("WitnetBridgeInterface")
var BlockRelayProxy = artifacts.require("BlockRelayProxy")

module.exports = function (deployer, network) {
  console.log(`> Migrating WBI into ${network} network`)
  deployer.deploy(WBI, BlockRelayProxy.address, 2)
}
