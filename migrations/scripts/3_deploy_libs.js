const realm = process.env.WITNET_EVM_REALM || "default"
const addresses = require("../addresses")[realm]
const settings = require("../settings")

let Witnet, CBOR

module.exports = function (deployer, network) {
  try {
    Witnet = artifacts.require(settings.artifacts[realm].Witnet || settings.artifacts.default.Witnet || "Witnet")
    CBOR = artifacts.require(settings.artifacts[realm].CBOR || settings.artifacts.default.CBOR || "CBOR")
  } catch {
    console.log("Skipped: libs artifacts not found.")
    return
  }

  network = network.split("-")[0]
  if (network in addresses) {
    Witnet.address = addresses[network].Witnet
  }

  if (!Witnet.isDeployed() || isNullAddress(Witnet.address)) {
    console.log(`> Migrating deployable Witnet libraries into "${realm}:${network}"...`)
    deployer.deploy(CBOR).then(function () {
      deployer.link(CBOR, Witnet)
      return deployer.deploy(Witnet)
    })
  } else {
    console.log()
    console.log(`> Skipped: 'Witnet' library deployed at ${Witnet.address}.`)
    console.log(`> Skipped: 'CBOR' library deployed at ${CBOR.address}.`)
  }
}

function isNullAddress (addr) {
  return !addr ||
    addr === "" ||
    addr === "0x0000000000000000000000000000000000000000" ||
    !web3.utils.isAddress(addr)
}
