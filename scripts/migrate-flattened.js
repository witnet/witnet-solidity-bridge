/* eslint-disable camelcase */
/* eslint-disable new-cap */
/* eslint-disable no-multi-str */
/* eslint-disable no-template-curly-in-string */

require("dotenv").config()

const exec = require("child_process").exec
const fs = require("fs")
const os = require("os")
const cli = new cli_func()

if (process.argv.length < 4) {
  console.log()
  console.log("\n\
    Usage: yarn migrate-flattened <Network> <ArtifactName>\n\
       or: npm run migrate-flattened <Network> <ArtifactName>\n\n\
  ")
  process.exit(0)
}

const network = process.argv[2]
const artifact = process.argv[3]
process.env.FLATTENED_DIRECTORY = `./flattened/${artifact}/`

if (!fs.existsSync(`${process.env.FLATTENED_DIRECTORY}/Flattened${artifact}.sol`)) {
  console.log("\n\
    > Please, flatten the artifact first. E.g.:\n\
      $ yarn flatten contracts" + (os.type() === "Windows_NT" ? "\\" : "/") + artifact + ".sol\n\n\
  ")
  process.exit(0)
}

compileFlattened().then(() => {
  console.log()
  migrateFlattened(network).then(() => {
    console.log()
  })
})
  .catch(err => {
    console.error("Fatal:", err)
    console.error()
    process.exit(1)
  })

/// /////////////////////////////////////////////////////////////////////////////

function cli_func () {
  this.exec = async function (cmd) {
    return new Promise((resolve, reject) => {
      exec(cmd, (error, stdout, stderr) => {
        if (error) {
          reject(error)
        } else {
          resolve(stdout)
        }
      }).stdout.pipe(process.stdout)
    })
  }
}

async function migrateFlattened (network) {
  console.log(
    "> Migrating from",
    process.env.FLATTENED_DIRECTORY,
    "into '" + (process.env.WITNET_EVM_REALM || "ethereum") + ":" + network + "'..."
  )
  await cli.exec(`truffle migrate --reset --config truffle-config.flattened.js --network ${network}`)
    .catch(err => {
      console.error(err)
      process.exit(1)
    })
}

async function compileFlattened () {
  console.log(`> Compiling from ${process.env.FLATTENED_DIRECTORY}...`)
  await cli.exec("truffle compile --all --config truffle-config.flattened.js")
    .catch(err => {
      console.error(err)
      process.exit(1)
    })
}
