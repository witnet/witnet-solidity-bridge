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
  saveJsonArtifact,
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
  network = network ? network.toLowerCase() : "development"
  if (network.indexOf(":") > -1) {
    return [network.split(":")[0], network]
  } else {
    return [null, network]
  }
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

function saveJsonArtifact (key, artifact) {
  const { abi, ast, bytecode, deployedBytecode, contractName } = artifact;
  const version = require("../../package.json").version
  const latest_fn = `./artifacts/${key}.json`
  const version_fn = `./artifacts/${key}-${version}.json`
  const current = {
    contractName,
    sourceName: ast?.absolutePath.split("project:/")[1],
    abi,
    bytecode,
    deployedBytecode
  };
  let latest = []
  if (fs.existsSync(latest_fn)) {
    try {
      latest = JSON.parse(fs.readFileSync(latest_fn))
    } catch {}
  }
  if (!isEqual(current, latest)) {
    const json = JSON.stringify(current, null, 4)
    fs.writeFileSync(version_fn, json, { flag: "w+" })
    fs.writeFileSync(latest_fn, json, { flag: "w+" })
  }
}