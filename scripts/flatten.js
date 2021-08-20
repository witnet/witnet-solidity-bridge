/* eslint-disable no-multi-str */

const exec = require("child_process").exec
const fs = require("fs")
const os = require("os")
const path = require("path")

if (process.argv.length < 3) {
  console.log("\n\
    Usage: yarn flatten </path/to/contracts/folder/ | /path/to/contract/file.sol>\n\
       or: npm run flatten </path/to/contracts/folder/ | /path/to/contract/file.sol>\n\n\
  ")
  process.exit(0)
}

try {
  createFolder("./flattened")
  const stats = fs.lstatSync(process.argv[2])
  if (stats.isFile()) {
    flatten(path.parse(process.argv[2]).dir, process.argv[2])
  } else if (stats.isDirectory()) {
    const basedir = path.normalize(process.argv[2]).replace(/\\/g, "/")
    const files = fs.readdirSync(basedir).filter(filename => filename.endsWith(".sol"))
    files.forEach(filename => {
      flatten(basedir, filename)
    })
    console.log(`\nProcessed ${files.length} Solidity files.`)
  }
} catch (e) {
  console.error("Fatal:", e)
  process.exit(1)
}

/// ////////////////////////////////////////////////////////////////////////////

function createFolder (folder) {
  if (!fs.existsSync(folder)) {
    if (os.type() === "Windows_NT") {
      folder = folder.replace(/\//g, "\\")
      exec(`mkdir ${folder}`)
    } else {
      exec(`mkdir -p ${folder}`)
    }
  }
}

function flatten (basedir, filepath) {
  const filename = path.parse(filepath).base
  const basename = path.parse(filepath).name
  const flattened = `flattened/${basename}/Flattened${basename}.sol`
  createFolder(`flattened/${basename}/`)
  if (fs.existsSync(flattened)) {
    console.log(`Skipping ${filename}: already flattened as '${flattened}'...`)
  } else {
    console.log(`Flattening ${filename} into '${flattened}'...`)
    exec(`npx truffle-flattener ${basedir}/${filename} > ${flattened}`)
  }
}
