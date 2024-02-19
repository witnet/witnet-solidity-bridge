#!/usr/bin/env node

const settings = require("../settings")
const utils = require("../src/utils")

if (process.argv.length < 3) {
    console.error(`\nUsage:\n\n$ node ./scripts/verify-proxies.js <ecosystem>:<network> ...OPTIONAL_ARGS\n`)
    process.exit(0)
}

const network = process.argv[2].toLowerCase().replaceAll(".", ":")

const header = network.toUpperCase()+ " LIBS";
console.info()
console.info(header)
console.info("=".repeat(header.length))
console.info()

const artifacts = settings.getArtifacts(network)
const libs = [
    artifacts["WitnetEncodingLib"],
    artifacts["WitnetErrorsLib"],
    artifacts["WitnetPriceFeedsLib"],
];
for (const index in libs) {
    utils.traceVerify(network, `${libs[index]}`);
}

