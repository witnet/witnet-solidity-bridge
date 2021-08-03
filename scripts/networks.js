require("dotenv").config()
const settings = require("../migrations/settings")
let realm = process.env.WITNET_EVM_REALM || "default"
console.log("Realm:", realm)
console.log("Networks:", settings.networks[realm])
