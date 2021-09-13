let addresses = require("../migrations/witnet.addresses")
let realm, network
if (process.argv.length >= 3) {
  network = process.argv[2].toLowerCase()
  realm = network.split(".")[0].toLowerCase()
  if (realm === "ethereum") realm = "default"
  if (!addresses[realm]) {
    console.log("Unknown realm:", realm)
    process.exit(1)
  }
  if (network.split(".")[1]) {
    if (!addresses[realm][network]) {
      console.log("Realm:", realm)
      console.log("Unknown network:", network)
      process.exit(1)
    }
    addresses = addresses[realm][network]
  } else {
    addresses = addresses[realm]
  }
}
console.log(addresses)
