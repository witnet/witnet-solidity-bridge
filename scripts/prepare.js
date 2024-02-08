const exec = require("child_process").execSync
const os = require("os")
const fs = require("fs")

if (fs.existsSync("./artifacts")) {
  if (os.type() === "Windows_NT") {
    exec(`del /s /q artifacts\\*.dbg.json`)
  } else {
    exec(`find ./artifacts -name '*.dbg.json' -exec rm -r {} \;`)
  }
}
