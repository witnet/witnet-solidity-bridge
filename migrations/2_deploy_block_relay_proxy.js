var BlockRelayProxy = artifacts.require("BlockRelayProxy")
const addresses = require("./addresses.json")

module.exports = function (deployer, network) {
  network = network.split("-")[0]
  console.log(network)
  if (network in addresses) {
    BlockRelayProxy.address = addresses[network].BlockRelayProxy
  } else {
    var MockBlockRelay = artifacts.require("MockBlockRelay")
    console.log(`> Migrating BlockRelay and BlockRelayProxy into ${network} network`)
    deployer.deploy(MockBlockRelay).then(function () {
      return deployer.deploy(BlockRelayProxy, MockBlockRelay.address)
    })
  }
}
