const WitnetRequestBoardProxy = artifacts.require("WitnetRequestBoardProxy")
const addresses = require("./addresses.json")

module.exports = function (deployer, network, accounts) {
  network = network.split("-")[0]
  console.log(network)
  if (network in addresses && addresses[network].WitnetRequestBoardProxy) {
    WitnetRequestBoardProxy.address = addresses[network].WitnetRequestBoardProxy
  } else {
    const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")
    console.log(`> Migrating WitnetRequestBoard and WitnetRequestBoardProxy into ${network} network`)
    deployer.deploy(WitnetRequestBoard, [accounts[0]]).then(function () {
      return deployer.deploy(WitnetRequestBoardProxy, WitnetRequestBoard.address)
    })
  }
}
