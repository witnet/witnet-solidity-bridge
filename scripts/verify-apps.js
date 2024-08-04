#!/usr/bin/env node

const settings = require("../settings")
const utils = require("../src/utils")

if (process.argv.length < 3) {
  console.error("\nUsage:\n\n$ node ./scripts/verify-apps.js <ecosystem>:<network> ...OPTIONAL_ARGS\n")
  process.exit(0)
}

const network = process.argv[2].toLowerCase().replaceAll(".", ":")

const header = network.toUpperCase() + " APPS"
console.info()
console.info(header)
console.info("=".repeat(header.length))
console.info()

const artifacts = settings.getArtifacts(network)
const apps = [
  artifacts.WitRandomness,
]
const constructorArgs = require("../migrations/constructorArgs.json")
if (!constructorArgs[network]) constructorArgs[network] = {}
for (const index in apps) {
  utils.traceVerify(network, `${apps[index]} --forceConstructorArgs string:${
    constructorArgs[network][apps[index]] || constructorArgs?.default[apps[index]]
  }`)
}
