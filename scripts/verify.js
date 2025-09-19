#!/usr/bin/env node

import hre from "hardhat";
import { verifyContract } from "@nomicfoundation/hardhat-verify/verify";
import { createRequire } from "module"
import merge from "lodash.merge"

const require = createRequire(import.meta.url);
const addresses = require("../migrations/addresses.json")
const constructorArgs = require("../migrations/constructorArgs.json")

import { default as settings } from "../settings/index.js"
import { default as utils } from "../src/utils.js"

const network = spliceFromArgs(process.argv, "--network")
const networkArtifacts = settings.getArtifacts(network)

async function main () {
  const framework = {
    libs: networkArtifacts.libs,
    core: networkArtifacts.core,
    apps: networkArtifacts.apps,
  }

  for (const domain in framework) {
    const header = network.toUpperCase() + " " + domain.toUpperCase()
    for (const base in framework[domain]) {
      const impl = framework[domain][base]
      let headline
      if (utils.isUpgradableArtifact(impl)) {
        // verify proxy
        const address = utils.getNetworkArtifactAddress(network, domain, addresses, base)
        headline = `> Verifying proxy for ${base}...`;
        console.info(`\n${"=".repeat(100)}\n${headline}`)
        await verifyContract({ address, contract: "contracts/core/WitnetProxy.sol:WitnetProxy" }, hre)
      }
      // verify logic
      const address = utils.getNetworkArtifactAddress(network, domain, addresses, impl)
      if (!address) {
        headline = `> SKIPPED: ${impl}`
        console.info(`\n${"=".repeat(100)}\n${headline}`)
        continue;
      } else {
        headline = `> Verifying ${impl}...`;
        console.info(`\n${"=".repeat(100)}\n${headline}`)
        const args = (
          constructorArgs[network][impl] || constructorArgs.default[impl] 
          ? merge(JSON.parse(constructorArgs[network][impl] || "[]"), JSON.parse(constructorArgs.default[impl] || "[]"))
          : undefined
        )?.values
        await verifyContract({ address, constructorArgs: args }, hre)
      }
    }
  }
}

function spliceFromArgs(args, flag) {
	const argIndex = args.indexOf(flag)
	if (argIndex >= 0 && args.length > argIndex + 1) {
		const value = args[argIndex + 1]
		args.splice(argIndex, 2)
		return value
	}
}

main().catch(err => {
  console.error(err)
  process.exitCode = 1
})

