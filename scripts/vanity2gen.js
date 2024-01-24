const { assert } = require("chai")
const create2 = require("./eth-create2")
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
  let prefix = "0x00"
  let suffix = "00"
  let hexArgs = ""
  process.argv.map((argv, index, args) => {
    if (argv === "--offset") {
      offset = parseInt(args[index + 1])
    } else if (argv === "--artifact") {
      artifact = artifacts.require(args[index + 1])
    } else if (argv === "--prefix") {
      prefix = args[index + 1].toLowerCase()
      assert(web3.utils.isHexStrict(prefix), "--prefix: invalid hex string")
    } else if (argv === "--suffix") {
      suffix = args[index + 1].toLowerCase()
      assert(web3.utils.isHexStrict(suffix), "--suffix: invalid hex string")
    } else if (argv === "--hits") {
      hits = parseInt(args[index + 1])
    } else if (argv === "--network") {
      [ecosystem, network] = utils.getRealmNetworkFromString(args[index + 1].toLowerCase())
    } else if (argv === "--hexArgs") {
      hexArgs = args[index + 1].toLowerCase()
      if (hexArgs.startsWith("0x")) hexArgs = hexArgs.slice(2)
      assert(web3.utils.isHexStrict("0x" + hexArgs), "--hexArgs: invalid hex string")
    } else if (argv === "--from") {
      from = args[index + 1]
    }
    return argv
  })
  try {
    from = from || addresses[ecosystem][network].WitnetDeployer
  } catch {
    console.error(`WitnetDeployer must have been previously deployed on network '${network}'.\n`)
    console.info("Usage:\n")
    console.info("  --artifact => Truffle artifact name (mandatory)")
    console.info("  --hexArgs  => Hexified constructor arguments")
    console.info("  --hits     => Number of vanity hits to look for (default: 10)")
    console.info("  --network  => Network name")
    console.info("  --offset   => Salt starting value minus 1 (default: 0)")
    console.info("  --prefix   => Prefix hex string to look for (default: 0x00)")
    console.info("  --suffix   => suffix hex string to look for (default: 0x00)")
    process.exit(1)
  }
  if (!artifact) {
    console.error("No --artifact was set!")
    process.exit(1)
  }
  const initCode = artifact.toJSON().bytecode + hexArgs
  console.log("Init code: ", initCode)
  console.log("Artifact:  ", artifact?.contractName)
  console.log("From:      ", from)
  console.log("Hits:      ", hits)
  console.log("Offset:    ", offset)
  console.log("Prefix:    ", prefix)
  console.log("Suffix:    ", suffix)
  console.log("=".repeat(55))
  suffix = suffix.slice(2)
  while (count < hits) {
    const salt = "0x" + utils.padLeft(offset.toString(16), "0", 32)
    const addr = create2(from, salt, initCode).toLowerCase()
    if (addr.startsWith(prefix) && addr.endsWith(suffix)) {
      const found = `${offset} => ${web3.utils.toChecksumAddress(addr)}`
      console.log(found)
      fs.appendFileSync(`./migrations/salts/${artifact?.contractName}$${from.toLowerCase()}.tmp`, found + "\n")
      count++
    }
    offset++
  }
}
