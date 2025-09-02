#!/usr/bin/env node

const addresses = require("../migrations/addresses.json")
const constructorArgs = require("../migrations/constructorArgs.json")
const settings = require("../settings")
const utils = require("../src/utils")

if (process.argv.length < 3) {
  console.error("\nUsage:\n\n$ node ./scripts/verify-core.js <ecosystem>:<network> ...OPTIONAL_ARGS\n")
  process.exit(0)
}

const network = process.argv[2].toLowerCase().replaceAll(".", ":")
const networkArtifacts = settings.getArtifacts(network)

utils.traceVerify(network, `${networkArtifacts?.WitnetDeployer} --forceConstructorArgs string: --verifiers etherscan,sourcify`)

const framework = {
  libs: networkArtifacts.libs,
  core: networkArtifacts.core,
  apps: networkArtifacts.apps,
}

for (const domain in framework) {
  const header = network.toUpperCase() + " " + domain.toUpperCase()
  console.info()
  console.info(header)
  console.info("=".repeat(header.length))
  console.info()
  for (const base in framework[domain]) {
    const impl = framework[domain][base]
    if (utils.isUpgradableArtifact(impl)) {
      const addr = utils.getNetworkArtifactAddress(network, domain, addresses, base)
      utils.traceVerify(network, `WitnetProxy@${addr} --custom-proxy WitnetProxy`)
    }
    const forceConstructorArgs = constructorArgs[network][impl]
    if (forceConstructorArgs) {
      utils.traceVerify(network, `${impl} --forceConstructorArgs string:${forceConstructorArgs} --verifiers etherscan,sourcify`)
    } else {
      utils.traceVerify(network, `${impl} --verifiers etherscan,sourcify`)
    }
  }
}
