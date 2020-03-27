const BlockRelayProxy = artifacts.require("BlockRelayProxy")
var WitnetRequestsBoardProxy = artifacts.require("WitnetRequestsBoardProxy")
const addresses = require("./addresses.json")

module.exports = function (deployer, network) {
  network = network.split("-")[0]
  console.log(network)
  if (network in addresses && addresses[network].WitnetRequestsBoardProxy) {
    WitnetRequestsBoardProxy.address = addresses[network].WitnetRequestsBoardProxy
  } else {
    const WitnetRequestsBoard = artifacts.require("WitnetRequestsBoard")
    console.log(`> Migrating WitnetRequestsBoard and WitnetRequestsBoardProxy into ${network} network`)
    deployer.deploy(WitnetRequestsBoard, BlockRelayProxy.address, 2).then(function () {
      return deployer.deploy(WitnetRequestsBoardProxy, WitnetRequestsBoard.address)
    })
  }
}
