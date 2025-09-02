const execSync = require("child_process").execSync
const fs = require("fs")
require("dotenv").config()
const readline = require("readline")

module.exports = {
  fromAscii,
  getNetworkAppsArtifactAddress,
  getNetworkArtifactAddress,
  getNetworkBaseArtifactAddress,
  getNetworkBaseImplArtifactAddresses,
  getNetworkCoreArtifactAddress,
  getNetworkLibsArtifactAddress,
  getNetworkTagsFromString,
  getRealmNetworkFromArgs,
  getRealmNetworkFromString,
  getWitnetArtifactsFromArgs,
  getWitOracleRequestMethodString,
  isDryRun,
  isNullAddress,
  isUpgradableArtifact,
  padLeft,
  prompt,
  readJsonFromFile,
  overwriteJsonFile,
  traceData,
  traceHeader,
  traceTx,
  traceVerify,
}

function fromAscii (str) {
  const arr1 = []
  for (let n = 0, l = str.length; n < l; n++) {
    const hex = Number(str.charCodeAt(n)).toString(16)
    arr1.push(hex)
  }
  return "0x" + arr1.join("")
}

function getNetworkAppsArtifactAddress (network, addresses, artifact) {
  const tags = getNetworkTagsFromString(network)
  for (const index in tags) {
    const network = tags[index]
    if (addresses[network] && addresses[network]?.apps && addresses[network].apps[artifact]) {
      return addresses[network].apps[artifact]
    }
  }
  return addresses?.default?.apps[artifact] ?? ""
}

function getNetworkBaseArtifactAddress (network, addresses, artifact) {
  const tags = getNetworkTagsFromString(network)
  for (const index in tags) {
    const network = tags[index]
    if (addresses[network] && addresses[network][artifact]) {
      return addresses[network][artifact]
    }
  }
  return addresses?.default[artifact] ?? ""
}

function getNetworkArtifactAddress (network, domain, addresses, artifact) {
  const tags = getNetworkTagsFromString(network)
  for (const index in tags) {
    const network = tags[index]
    if (addresses[network] && addresses[network][domain] && addresses[network][domain][artifact]) {
      return addresses[network][domain][artifact]
    }
  }
  return addresses?.default[domain][artifact] ?? ""
}

function getNetworkBaseImplArtifactAddresses (network, domain, addresses, base, exception) {
  const entries = []
  const tags = ["default", ...getNetworkTagsFromString(network)]
  for (const index in tags) {
    const network = tags[index]
    if (addresses[network] && addresses[network][domain]) {
      Object.keys(addresses[network][domain]).forEach(impl => {
        if (
          (!exception || impl !== exception) &&
          impl !== base &&
          impl.indexOf(base) === 0 &&
          addresses[network][domain][impl] !== undefined &&
          !entries.map(entry => entry?.impl).includes(impl)
        ) {
          entries.push({ impl, addr: addresses[network][domain][impl] })
        }
      })
    }
  }
  return entries
}

function getNetworkCoreArtifactAddress (network, addresses, artifact) {
  const tags = getNetworkTagsFromString(network)
  for (const index in tags) {
    const network = tags[index]
    if (addresses[network] && addresses[network]?.core && addresses[network].core[artifact]) {
      return addresses[network].core[artifact]
    }
  }
  return addresses?.default?.core[artifact] ?? ""
}

function getNetworkLibsArtifactAddress (network, addresses, artifact) {
  const tags = getNetworkTagsFromString(network)
  for (const index in tags) {
    const network = tags[index]
    if (addresses[network] && addresses[network]?.libs && addresses[network].libs[artifact]) {
      return addresses[network].libs[artifact]
    }
  }
  return addresses?.default?.libs?.[artifact] ?? ""
}

function getNetworkTagsFromString (network) {
  network = network ? network.toLowerCase() : "development"
  const tags = []
  const parts = network.split(":")
  for (let ix = 0; ix < parts.length; ix++) {
    tags.push(parts.slice(0, ix + 1).join(":"))
  }
  return tags
}

function getRealmNetworkFromArgs () {
  let networkString = process.env.WSB_DEFAULT_CHAIN || process.argv.includes("test") ? "test" : "development"
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

function getWitOracleRequestMethodString (method) {
  if (!method) {
    return "HTTP-GET"
  } else {
    const strings = {
      0: "UNKNOWN",
      1: "HTTP-GET",
      2: "RNG",
      3: "HTTP-POST",
      4: "HTTP-HEAD",
    }
    return strings[method] || method.toString()
  }
}

function getWitnetArtifactsFromArgs () {
  let selection = []
  process.argv.map((argv, index, args) => {
    if (argv === "--artifacts") {
      selection = args[index + 1].split(",")
    }
    return argv
  })
  if (selection.length === 0) {
    process.argv[2]?.split(" ").map((argv, index, args) => {
      if (argv === "--artifacts") {
        selection = args[index + 1].split(",")
      }
      return argv
    })
  }
  return selection
};

function isDryRun (network) {
  return network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
}

function isNullAddress (addr) {
  return !addr ||
      addr === "" ||
      addr === "0x0000000000000000000000000000000000000000"
}

function isUpgradableArtifact (impl) {
  return (
    impl.indexOf("Upgradable") > -1 || impl.indexOf("Trustable") > -1
  )
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

async function readJsonFromFile (filename) {
  // lockfile.lockSync(filename)
  const json = JSON.parse(await fs.readFileSync(filename))
  // lockfile.unlockSync(filename)
  return json || {}
}

async function overwriteJsonFile (filename, extra) {
  // lockfile.lockSync(filename)
  const json = { ...JSON.parse(fs.readFileSync(filename)), ...extra }
  fs.writeFileSync(filename, JSON.stringify(json, null, 4), { flag: "w+" })
  // lockfile.unlockSync(filename)
}

function traceData (header, data, width, color) {
  process.stdout.write(header)
  if (color) process.stdout.write(color)
  for (let ix = 0; ix < data.length / width; ix++) {
    if (ix > 0) process.stdout.write(" ".repeat(header.length))
    process.stdout.write(data.slice(width * ix, width * (ix + 1)))
    process.stdout.write("\n")
  }
  if (color) process.stdout.write("\x1b[0m")
}

function traceHeader (header) {
  console.info("")
  console.info("  ", header)
  console.info("  ", `${"-".repeat(header.length)}`)
}

function traceTx (tx) {
  console.info("  ", "> EVM tx sender:     \x1b[93m", tx.receipt.from, "\x1b[0m")
  console.info("  ", "> EVM tx hash:       \x1b[33m", tx.receipt.transactionHash.slice(2), "\x1b[0m")
  console.info("  ", "> EVM tx gas used:   ",
    `\x1b[33m${tx.receipt.gasUsed.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")}\x1b[0m`
  )
  if (tx.receipt?.effectiveGasPrice) {
    console.info("  ", "> EVM tx gas price:  ", `\x1b[33m${tx.receipt.effectiveGasPrice / 10 ** 9}`, "gwei\x1b[0m")
    console.info("  ", "> EVM tx total cost: ", `\x1b[33m${parseFloat(
      (BigInt(tx.receipt.gasUsed) * BigInt(tx.receipt.effectiveGasPrice)) /
        BigInt(10 ** 18)
    ).toString()}`,
    "ETH\x1b[0m"
    )
  }
}

function traceVerify (network, verifyArgs) {
  console.info(
    execSync(
      `npx truffle run verify --network ${network} ${verifyArgs} ${process.argv.slice(3)}`,
      { stdout: "inherit" }
    ).toString().split("\n")
      .join("\n")
  )
}
