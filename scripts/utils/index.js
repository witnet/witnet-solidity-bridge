const fs = require("fs")
require("dotenv").config()
const { isEqual } = require("lodash")
const readline = require("readline")
const web3 = require("web3")

const traceHeader = require("./traceHeader")
const traceTx = require("./traceTx")

module.exports = {
  fromAscii,
  getRealmNetworkFromArgs,
  getRealmNetworkFromString,
  isNullAddress,
  padLeft,
  prompt,
  saveAddresses,
  saveJsonAbi,
  traceHeader,
  traceTx,
}

function fromAscii (str) {
  const arr1 = []
  for (let n = 0, l = str.length; n < l; n++) {
    const hex = Number(str.charCodeAt(n)).toString(16)
    arr1.push(hex)
  }
  return "0x" + arr1.join("")
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
  network = network ? network.replaceAll(":", ".").toLowerCase() : "development"

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

function padLeft (str, char, size) {
  if (str.length < size) {
    return char.repeat((size - str.length) / char.length) + str
  } else {
    return str
  }
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

function saveAddresses (addrs) {
  fs.writeFileSync(
    "./migrations/witnet.addresses.json",
    JSON.stringify(addrs, null, 4),
    { flag: "w+" }
  )
}

function saveJsonAbi (key, abi) {
  const version = require("../../package.json").version
  const latest_fn = `./migrations/abis/${key}.json`;
  const version_fn = `./migrations/abis/${key}-${version}.json`
  let latest_abi = []
  if (fs.existsSync(latest_fn)) {
    try {
      latest_abi = JSON.parse(fs.readFileSync(latest_fn))
    } catch {}
  }
  if (!isEqual(abi, latest_abi)) {
    const json = JSON.stringify(abi, null, 4)
    if (fs.existsSync(latest_fn)) {
      // avoid creating versioned abi upon first deployment
      fs.writeFileSync(version_fn, json, { flag: "w+" })
    }
    fs.writeFileSync(latest_fn, json, { flag: "w+" })
  }
}
