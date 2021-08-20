/* eslint-disable camelcase */
/* eslint-disable new-cap */
/* eslint-disable no-multi-str */
/* eslint-disable no-template-curly-in-string */

require("dotenv").config()

const settings = require("../migrations/witnet.settings")
const realm = process.env.WITNET_EVM_REALM || "default"

const exec = require("child_process").exec
const fs = require("fs")
const cli = new cli_func()

if (process.argv.length < 3) {
  console.log()
  console.log("\n\
    Usage: yarn migrate <Network>\n\
       or: npm run migrate <Network>\n\n\
  ")
  process.exit(0)
}

const network = process.argv[2]
if (!settings.networks[realm][network]) {
  console.error(`\n!!! Network "${realm}:${network}" not found.\n`)
  console.error(`> Available networks in realm "${realm}":`)
  console.error(settings.networks[realm])
  process.exit(0)
}

const artifact = (settings.artifacts[realm] && settings.artifacts[realm].WitnetRequestBoard) ||
  settings.artifacts.default.WitnetRequestBoard
process.env.FLATTENED_DIRECTORY = `./flattened/${artifact}/`
if (!fs.existsSync(`${process.env.FLATTENED_DIRECTORY}/Flattened${artifact}.sol`)) {
  console.log("\n\
    > Please, flatten Witnet artifacts first. E.g.:\n\
      $ yarn flatten:witnet\n\n\
  ")
  process.exit(0)
}

migrateFlattened(network)

/// /////////////////////////////////////////////////////////////////////////////

async function migrateFlattened (network) {
  console.log(
    `> Migrating from ${process.env.FLATTENED_DIRECTORY} into "${realm}:${network}"..."`
  )
  await cli.exec(`truffle migrate --reset --config truffle-config.flattened.js --network ${network}`)
    .catch(err => {
      console.error(err)
      process.exit(1)
    })
}

function cli_func () {
  this.exec = async function (cmd) {
    return new Promise((resolve, reject) => {
      exec(cmd, (error, stdout, stderr) => {
        if (error) {
          reject(error)
          return
        }
        resolve(stdout)
      }).stdout.pipe(process.stdout)
    })
  }
}
