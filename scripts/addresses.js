require("dotenv").config()

let addresses = require("../migrations/addresses")
let realm, network

if (process.argv.length >= 3) {
  realm = process.argv[2]
  if (!addresses[realm]) {
    console.log("Unknown realm:", realm)
    process.exit(0)
  }

  if (process.argv.length >= 4) {
    network = process.argv[3]
    if (!addresses[realm][network]) {
      if (!addresses[realm][`${realm}.${network}`]) {
        console.log("Realm:", realm)
        console.log("Unknown network:", network)
        process.exit(0)
      } else {
        addresses = addresses[realm][`${realm}.${network}`]
      }      
    } else {
      addresses = addresses[realm][network]
    }    
  } else {
    addresses = addresses[realm]
  }
}
console.log(addresses)
