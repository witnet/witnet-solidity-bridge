const fs = require("fs")

const create3 = require("./eth-create3.cjs")
const utils = require("../src/utils.js").default

const addresses = require("../migrations/addresses")

module.exports = async function () {
  let count = 0
  let from
  let hits = 10
  let offset = 0
  let network = "default"
  let prefix = "0x00"
  let suffix = "0x00"
  process.argv.map((argv, index, args) => {
    if (argv === "--offset") {
      offset = parseInt(args[index + 1])
    } else if (argv === "--prefix") {
      prefix = args[index + 1].toLowerCase()
      if (!web3.utils.isHexStrict(prefix)) {
        throw Error("--prefix: invalid hex string")
      }
    } else if (argv === "--suffix") {
      suffix = args[index + 1].toLowerCase()
      if (!web3.utils.isHexStrict(suffix)) {
        throw Error("--suffix: invalid hex string")
      }
    } else if (argv === "--hits") {
      hits = parseInt(args[index + 1])
    } else if (argv === "--network") {
      [, network] = utils.getRealmNetworkFromString(args[index + 1].toLowerCase())
    } else if (argv === "--from") {
      from = args[index + 1]
    }
    return argv
  })
  try {
    from = from || addresses[network]?.WitnetDeployer || addresses.default.WitnetDeployer
  } catch {
    console.error(`WitnetDeployer must have been previously deployed on network '${network}'.\n`)
    console.info("Usage:\n")
    console.info("  --hits     => Number of vanity hits to look for (default: 10)")
    console.info("  --network  => Network name")
    console.info("  --offset   => Salt starting value minus 1 (default: 0)")
    console.info("  --prefix   => Prefix hex string to look for (default: 0x00)")
    console.info("  --suffix   => suffix hex string to look for (default: 0x00)")
    process.exit(1)
  }
  console.log("From:      ", from)
  console.log("Hits:      ", hits)
  console.log("Offset:    ", offset)
  console.log("Prefix:    ", prefix)
  console.log("Suffix:    ", suffix)
  console.log("=".repeat(55))
  suffix = suffix.slice(2)
  while (count < hits) {
    const salt = "0x" + utils.padLeft(offset.toString(16), "0", 32)
    const addr = create3(from, salt).toLowerCase()
    if (addr.startsWith(prefix) && addr.endsWith(suffix)) {
      const found = `${offset} => ${web3.utils.toChecksumAddress(addr)}`
      console.log(found)
      fs.appendFileSync(`./migrations/salts/create3$${from.toLowerCase()}.tmp`, found + "\n")
      count++
    }
    offset++
  }
}
