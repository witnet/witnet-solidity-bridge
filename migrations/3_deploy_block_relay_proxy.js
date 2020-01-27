var BlockRelayProxy = artifacts.require("BlockRelayProxy")
var MockBlockRelay = artifacts.require("MockBlockRelay")

module.exports = function (deployer, network) {
  console.log(`> Migrating BlockRelayProxy into ${network} network`)
  deployer.deploy(BlockRelayProxy, MockBlockRelay.address)
}
