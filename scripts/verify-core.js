#!/usr/bin/env node

const utils = require("../src/utils")

if (process.argv.length < 3) {
  console.error("\nUsage:\n\n$ node ./scripts/verify-proxies.js <ecosystem>:<network> ...OPTIONAL_ARGS\n")
  process.exit(0)
}

const network = process.argv[2].toLowerCase().replaceAll(".", ":")

const header = network.toUpperCase() + " CORE"
console.info()
console.info(header)
console.info("=".repeat(header.length))
console.info()

utils.traceVerify(network, "WitnetDeployer")
utils.traceVerify(network, "WitnetProxy")

const singletons = [
  "WitnetOracle",
  "WitnetPriceFeeds",
  "WitnetRequestBytecodes",
  "witnetRequestFactory",
]
for (const index in singletons) {
  utils.traceVerify(network, `${singletons[index]} --custom-proxy WitnetProxy`)
}
