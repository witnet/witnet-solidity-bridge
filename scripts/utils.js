require("dotenv").config()
const readline = require("readline")
const web3 = require("web3")

module.exports = {
  getRealmNetworkFromArgs,
  getRealmNetworkFromString,
  isNullAddress,
  prompt,
}

function getRealmNetworkFromArgs () {
  let networkString = process.argv.includes("test") ? "test" : "development"
  // If a `--network` argument is provided, use that instead
  const args = process.argv.join("=").split("=")
  const networkIndex = args.indexOf("--network")
  if (networkIndex >= 0) {
    networkString = args[networkIndex + 1]
  }
  return getRealmNetworkFromString(networkString)
}

function getRealmNetworkFromString (network) {
  network = network ? network.toLowerCase() : "development"

  // Try to extract realm/network info from environment
  const envRealm = process.env.WITNET_EVM_REALM
    ? process.env.WITNET_EVM_REALM.toLowerCase()
    : null

  let realm
  if (network.split(".")[1]) {
    realm = network.split(".")[0]
    if (realm === "ethereum") {
      // Realm in "ethereum.*" networks must be set to "default"
      realm = "default"
    }
    if (envRealm && realm !== envRealm) {
      // Check that WITNET_EVM_REALM, if defined, and network's realm actually match
      console.error(
        `\n> Fatal: network "${network}" and WITNET_EVM_REALM value`,
        `("${envRealm.toUpperCase()}") don't match.\n`
      )
      process.exit(1)
    }
  } else {
    realm = envRealm || "default"
    network = `${realm === "default" ? "ethereum" : realm}.${network}`
  }
  if (realm === "default") {
    const subnetwork = network.split(".")[1]
    if (subnetwork === "development" || subnetwork === "test") {
      // In "default" realm, networks "development" and "test" must be returned without a prefix.
      network = subnetwork
    }
  }
  return [realm, network]
}

function isNullAddress (addr) {
  return !addr ||
      addr === "0x0000000000000000000000000000000000000000" ||
      !web3.utils.isAddress(addr)
}

async function prompt (text) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  })
  let answer
  await new Promise((resolve) => {
    rl.question(
      text,
      function (input) {
        answer = input
        rl.close()
      })
    rl.on("close", function () {
      resolve()
    })
  })
  return answer
}
