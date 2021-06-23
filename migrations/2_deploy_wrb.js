const addresses = require("./addresses.json")

const Witnet = artifacts.require("Witnet")
const WitnetProxy = artifacts.require("WitnetProxy")

module.exports = async function (deployer, network, accounts) {
  network = network.split("-")[0]
  if (network in addresses && addresses[network].WitnetProxy) {
    WitnetProxy.address = addresses[network].WitnetProxy
  } else {
    const WitnetRequestBoard = artifacts.require("WitnetRequestBoard")
    console.log(`> Migrating WitnetRequestBoard and WitnetProxy into ${network} network...`)
    await deployer.link(Witnet, [WitnetRequestBoard])
    const wrb = await deployer.deploy(WitnetRequestBoard)
    const proxy = await deployer.deploy(WitnetProxy)
    await proxy.upgrade(
      wrb.address,
      web3.eth.abi.encodeParameter(
        "address[]",
        [accounts[0]]
      )
    )
  }
}
