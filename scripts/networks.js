let networks = require("../migrations/witnet.settings").networks
let realm, network
if (process.argv.length >= 3) {
  network = process.argv[2].toLowerCase()
  realm = network.split(".")[0].toLowerCase()
  if (realm === "ethereum") realm = "default"
  if (!networks[realm]) {
    console.log("Unknown realm:", realm)
    process.exit(1)
  }
  if (network.split(".")[1]) {
    if (!networks[realm][network]) {
      console.log("Realm:", realm)
      console.log("Unknown network:", network)
      process.exit(1)
    }
    networks = networks[realm][network]
  } else {
    networks = networks[realm]
  }
}
console.log(networks)
