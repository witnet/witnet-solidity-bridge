const { assert } = require("chai")
const create2 = require("eth-create2")
const fs = require("fs")
const utils = require("./utils")

const addresses = require("../migrations/witnet.addresses")

module.exports = async function () {
  let artifact
  let count = 0
  let ecosystem = "default"
  let from
  let hits = 10
  let offset = 0
  let network = "default"
  let target = "0xfacade"
  process.argv.map((argv, index, args) => {
    if (argv === "--from") {
      from = args[index + 1]
    } else if (argv === "--offset") {
      offset = parseInt(args[index + 1])
    } else if (argv === "--artifact") {
      artifact = artifacts.require(args[index + 1])
    } else if (argv === "--target") {
      target = args[index + 1].toLowerCase()
      assert(web3.utils.isHexStrict(target), "--target refers invalid hex string")
    } else if (argv === "--hits") {
      hits = parseInt(args[index + 1])
    } else if (argv === "--network") {
      [ecosystem, network] = utils.getRealmNetworkFromString(args[index + 1].toLowerCase())
    }
    return argv
  })
  try {
    from = from || addresses[ecosystem][network].Create2Factory
  } catch {
    console.error(` Create2Factory must have been previously deployed on network '${network}'.\n`)
    console.info("Usage:\n")
    console.info("  --artifact => Truffle artifact name (default: WitnetProxy)")
    console.info("  --hits     => Number of vanity hits to look for (default: 10)")
    console.info("  --offset   => Salt starting value minus 1 (default: 0)")
    console.info("  --network  => Network name")
    console.info("  --target   => Prefix hex number to look for (default: 0xc0ffee)")
    process.exit(1)
  }
  const bytecode = artifact
    ? artifact.toJSON().bytecode
    : `0x3d602d80600a3d3981f3363d3d373d3d3d363d73${from.toLowerCase().slice(2)}5af43d82803e903d91602b57fd5bf3`
  console.log("Bytecode:  ", bytecode)
  console.log("Artifact:  ", artifact?.contractName || "ERC-1167: Minimal Proxy Contract")
  console.log("From:      ", from)
  console.log("Hits:      ", hits)
  console.log("Offset:    ", offset)
  console.log("Target:    ", target)
  console.log("=".repeat(55))
  while (count < hits) {
    const salt = "0x" + utils.padLeft(offset.toString(16), "0", 32)
    const addr = create2(from, salt, bytecode)
    if (addr.toLowerCase().startsWith(target)) {
      const found = `${offset} => ${web3.utils.toChecksumAddress(addr)}`
      console.log(found)
      fs.appendFileSync(`./migrations/salts/${artifact?.contractName || "MinimalProxy"}$${from.toLowerCase()}.tmp`, found + "\n")
      count++
    }
    offset++
  }
}
