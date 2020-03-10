var WRB = artifacts.require("WitnetRequestsBoard")
var BlockRelayProxy = artifacts.require("BlockRelayProxy")

module.exports = function (deployer, network) {
  console.log(`> Migrating WRB into ${network} network`)
  deployer.deploy(WRB, BlockRelayProxy.address, 2)
}
