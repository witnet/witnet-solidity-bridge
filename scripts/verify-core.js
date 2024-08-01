#!/usr/bin/env node

const settings = require("../settings")
const utils = require("../src/utils")

if (process.argv.length < 3) {
  console.error("\nUsage:\n\n$ node ./scripts/verify-core.js <ecosystem>:<network> ...OPTIONAL_ARGS\n")
  process.exit(0)
}

const network = process.argv[2].toLowerCase().replaceAll(".", ":")

const header = network.toUpperCase() + " CORE"
console.info()
console.info(header)
console.info("=".repeat(header.length))
console.info()

utils.traceVerify(network, settings.getArtifacts(network).WitnetDeployer)
utils.traceVerify(network, "WitnetProxy")

const addresses = require("../migrations/addresses.json")
const singletons = [
  "WitnetOracle",
  "WitnetPriceFeeds",
  "WitnetRadonRegistry",
  "WitnetRequestFactory",
]
for (const index in singletons) {
  utils.traceVerify(network, `WitnetProxy@${
    addresses[network][singletons[index]] || addresses.default[singletons[index]]
  } --custom-proxy WitnetProxy`)
}
