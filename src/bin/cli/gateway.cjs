const helpers = require("../helpers.cjs")

const { spawn } = require("node:child_process")
const os = require("os")

module.exports = async function (flags = {}, args = []) {
  [args] = helpers.deleteExtraFlags(args)
  const network = args[0]
  if (!network) {
    throw new Error("No EVM network was specified.")
  } else if (network && !helpers.supportsNetwork(network)) {
    throw new Error(`Unsupported network "${network}"`)
  } else {
    const shell = spawn(
      os.type() === "Windows_NT" ? "npx.cmd" : "npx", [
        "ethrpc",
        network,
        flags?.port || 8545,
        flags?.remote,
      ],
      { shell: true }
    )
    shell.stdout.on("data", (x) => {
      process.stdout.write(x.toString())
    })
    shell.stderr.on("data", (x) => {
      process.stderr.write(x.toString())
    })
  }
}
