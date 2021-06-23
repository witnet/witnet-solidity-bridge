const CBOR = artifacts.require("CBOR")
const Witnet = artifacts.require("Witnet")

module.exports = function (deployer, network) {
  console.log(`> Migrating CBOR and Witnet into ${network} network`)
  deployer.deploy(CBOR).then(function () {
    deployer.link(CBOR, Witnet)
    return deployer.deploy(Witnet)
  })
}
