require("dotenv").config()

module.exports = {
  getRealmNetworkFromArgs,
  getRealmNetworkFromNetwork,
}

function getRealmNetworkFromArgs () {
  let realm = process.env.WITNET_EVM_REALM
    ? process.env.WITNET_EVM_REALM.toLowerCase()
    : "default"
  let network = "development"
  const args = process.argv.join("=").split("=")
  const networkIndex = args.indexOf("--network")
  if (networkIndex >= 0) {
    network = args[networkIndex + 1]
    realm = (network || "default").split(".")[0]
  }
  if (realm === "ethereum") realm = "default"
  return [realm, network]
}

function getRealmNetworkFromNetwork (network) {
  network = network || "development"
  let realm = "default"
  if (!network.split(".")[1]) {
    network = `ethereum.${network}`
  } else {
    realm = network.split(".")[0]
    if (realm === "ethereum") {
      realm = "default"
    }
  }
  return [realm, network]
}
