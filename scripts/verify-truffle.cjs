#!/usr/bin/env node

const addresses = require("../migrations/addresses.json")
const constructorArgs = require("../migrations/constructorArgs.json")
const settings = require("../settings/index.js").default
const utils = require("../src/utils.js").default

const web3 = require("web3")

if (process.argv.length < 3) {
	console.error(
		"\nUsage:\n\n$ node ./scripts/verify-core.js <ecosystem>:<network> ...OPTIONAL_ARGS\n",
	)
	process.exit(0)
}

const network = process.argv[2].toLowerCase().replaceAll(".", ":")
const networkArtifacts = settings.getArtifacts(network)

utils.traceVerifyTruffle(
	network,
	`${networkArtifacts?.WitnetDeployer} --forceConstructorArgs string: --verifiers etherscan,sourcify`,
)

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
			const addr = utils.getNetworkArtifactAddress(
				network,
				domain,
				addresses,
				base,
			)
			utils.traceVerifyTruffle(
				network,
				`WitnetProxy@${addr} --custom-proxy WitnetProxy`,
			)
		}
		const forceConstructorArgs =
			constructorArgs[network][impl] || constructorArgs?.default[impl]
		if (forceConstructorArgs) {
			const args = JSON.parse(forceConstructorArgs)
			const encodedArgs = web3.eth.abi
				.encodeParameters(args.types, args.values)
				.slice(2)
			utils.traceVerifyTruffle(
				network,
				`${impl} --forceConstructorArgs string:${encodedArgs} --verifiers etherscan,sourcify`,
			)
		} else {
			utils.traceVerifyTruffle(
				network,
				`${impl} --verifiers etherscan,sourcify`,
			)
		}
	}
}
