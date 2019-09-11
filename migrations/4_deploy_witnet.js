var CBOR = artifacts.require("CBOR")
var Witnet = artifacts.require("Witnet")

module.exports = function (deployer, network) {
  console.log(`> Migrating CBOR and Witnet into ${network} network`)
  deployer.deploy(CBOR)
  deployer.link(CBOR, Witnet)
  deployer.deploy(Witnet)
}
