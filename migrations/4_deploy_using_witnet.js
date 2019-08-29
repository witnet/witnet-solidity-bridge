var CBOR = artifacts.require("CBOR")
var Witnet = artifacts.require("Witnet")
var UsingWitnet = artifacts.require("UsingWitnet")
var UsingWitnetBytes = artifacts.require("UsingWitnetBytes")
var WBI = artifacts.require("WitnetBridgeInterface")

module.exports = function (deployer, network, accounts) {
  console.log(`> Migrating CBOR, Witnet, UsingWitnet and UsingWitnetBytes into ${network} network`)

  deployer.deploy(CBOR)

  deployer.link(CBOR, Witnet)
  deployer.deploy(Witnet)

  deployer.link(Witnet, UsingWitnet)
  deployer.deploy(UsingWitnet, WBI.address)
  deployer.deploy(UsingWitnetBytes, WBI.address)
}
