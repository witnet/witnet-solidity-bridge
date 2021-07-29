const addresses = require("./addresses.json")
const Witnet = artifacts.require("Witnet")

module.exports = function (deployer, network) {
  network = network.split("-")[0]
  if (network in addresses && addresses[network].Witnet) {
    Witnet.address = addresses[network].Witnet
  } else {
    console.log(`> Migrating deployable Witnet libraries into "${network}" network...`)
    const CBOR = artifacts.require("CBOR")
    deployer.deploy(CBOR).then(function () {
      deployer.link(CBOR, Witnet)
      return deployer.deploy(Witnet)
    })
  }
}
