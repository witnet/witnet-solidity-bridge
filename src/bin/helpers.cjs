const fs = require("fs")
const merge = require("lodash.merge")

const addresses = require("../../migrations/addresses.json")
const artifacts = require("../../migrations/settings/artifacts.js").default
const constructorArgs = require("../../migrations/constructorArgs.json")

const DEFAULT_BATCH_SIZE = 64
const DEFAULT_LIMIT = 64
const DEFAULT_SINCE = -5000
const WITNET_SDK_RADON_ASSETS_PATH = process.env.WITNET_SDK_RADON_ASSETS_PATH || "../../../../witnet/assets"

const isModuleInitialized = fs.existsSync("./witnet/assets/index.cjs")

function* chunks(arr, n) {
  for (let i = 0; i < arr.length; i += n) {
    yield arr.slice(i, i + n)
  }
}

const colors = {
  blue: (str) => `\x1b[34m${str}\x1b[0m`,
  cyan: (str) => `\x1b[36m${str}\x1b[0m`,
  gray: (str) => `\x1b[90m${str}\x1b[0m`,
  green: (str) => `\x1b[32m${str}\x1b[0m`,
  magenta: (str) => `\x1b[0;35m${str}\x1b[0m`,
  red: (str) => `\x1b[31m${str}\x1b[0m`,
  yellow: (str) => `\x1b[33m${str}\x1b[0m`,
  white: (str) => `\x1b[0;38m${str}\x1b[0m`,
  lblue: (str) => `\x1b[1;94m${str}\x1b[0m`,
  lcyan: (str) => `\x1b[1;96m${str}\x1b[0m`,
  lgreen: (str) => `\x1b[1;92m${str}\x1b[0m`,
  lmagenta: (str) => `\x1b[1;95m${str}\x1b[0m`,
  lwhite: (str) => `\x1b[0;1;98m${str}\x1b[0m`,
  lyellow: (str) => `\x1b[1;93m${str}\x1b[0m`,
  mblue: (str) => `\x1b[94m${str}\x1b[0m`,
  mcyan: (str) => `\x1b[96m${str}\x1b[0m`,
  mgreen: (str) => `\x1b[92m${str}\x1b[0m`,
  mmagenta: (str) => `\x1b[0;95m${str}\x1b[0m`,
  mred: (str) => `\x1b[91m${str}\x1b[0m`,
  myellow: (str) => `\x1b[93m${str}\x1b[0m`,
}

const colorstrip = (str) => str.replace(
  /[\u001b\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]/g, ""
)

const commas = (number) => {
  const parts = number?.toString().split(".") || [""]
  const result = parts.length <= 1
    ? `${parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`
    : `${parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")}.${parts[1]}`
  return result
}

function deleteExtraFlags(args) {
  const deleted = []
  return [
    args?.filter(arg => {
      if (arg.startsWith("--")) {
        deleted.push(arg.slice(2))
        return false
      } else {
        return true
      }
    }),
    deleted,
  ]
}

function extractFlagsFromArgs(args, flags) {
  const curated = {}
  if (args && Array.isArray(args) && flags) {
    flags.forEach(flag => {
      const index = args.indexOf(`--${flag}`)
      if (index >= 0) {
        curated[flag] = true
        args.splice(index, 1)
      }
    })
  }
  return [args || [], curated]
}

function extractOptionsFromArgs(args, options) {
  const curated = {}
  if (args && Array.isArray(args) && options) {
    options.forEach(option => {
      const index = args.indexOf(`--${option}`)
      if (index >= 0) {
        curated[option] = args[index]
        if (!args[index + 1] || args[index + 1].startsWith("--")) {
          args.splice(index, 1)
          curated[option] = undefined
        } else {
          curated[option] = args[index + 1]
          args.splice(index, 2)
        }
      }
    })
  }
  return [args || [], curated]
}

function flattenObject(ob) {
  const toReturn = {}
  for (const i in ob) {
    if (!ob.hasOwnProperty(i)) continue
    if ((typeof ob[i]) === "object" && ob[i] !== null) {
      const flatObject = flattenObject(ob[i])
      for (const x in flatObject) {
        if (!flatObject.hasOwnProperty(x)) continue
        toReturn[i + "." + x] = flatObject[x]
      }
    } else {
      toReturn[i] = ob[i]
    }
  }
  return toReturn
}

function getNetworkAddresses(network) {
  let res = addresses?.default
  getNetworkTagsFromString(network).forEach(net => {
    res = merge(res, addresses[net])
  })
  return merge(
    res,
    fs.existsSync(`${WITNET_SDK_RADON_ASSETS_PATH}/../addresses.json`)
      ? require(`${WITNET_SDK_RADON_ASSETS_PATH}/../addresses.json`)[network.toLowerCase()]
      : {},
  )
}

function getNetworkArtifacts(network) {
  let res = artifacts?.default
  getNetworkTagsFromString(network).forEach(net => {
    res = merge(res, artifacts[net])
  })
  return res
}

function getNetworkConstructorArgs(network) {
  let res = {}
  getNetworkTagsFromString(network).forEach(net => {
    res = merge(res, constructorArgs[net])
  })
  return res
}

function getNetworkTagsFromString(network) {
  network = network ? network.toLowerCase() : "development"
  const tags = []
  const parts = network.split(":")
  for (let ix = 0; ix < parts.length; ix++) {
    tags.push(parts.slice(0, ix + 1).join(":"))
  }
  return tags
}

function importRadonAssets(options) {
  const { assets } = options?.legacy ? {} : require("@witnet/sdk")
  return isModuleInitialized && fs.existsSync(`${WITNET_SDK_RADON_ASSETS_PATH}/index.cjs`)
    ? merge(assets, require(`${WITNET_SDK_RADON_ASSETS_PATH}/index.cjs`))
    : assets
}

function orderKeys(obj) {
  const keys = Object.keys(obj).sort(function keyOrder(k1, k2) {
    if (k1 < k2) return -1
    else if (k1 > k2) return +1
    else return 0
  })
  let i; const after = {}
  for (i = 0; i < keys.length; i++) {
    after[keys[i]] = obj[keys[i]]
    delete obj[keys[i]]
  }
  for (i = 0; i < keys.length; i++) {
    obj[keys[i]] = after[keys[i]]
  }
  return obj
}

function prompter(promise) {
  const loading = (() => {
    const h = ["|", "/", "-", "\\"]
    let i = 0
    return setInterval(() => {
      i = (i > 3) ? 0 : i
      process.stdout.write(`\b\b${h[i]} `)
      i++
    }, 50)
  })()
  return promise
    .then(result => {
      clearInterval(loading)
      process.stdout.write("\b\b")
      return result
    })
}

function readWitnetJsonFiles(...filenames) {
  return Object.fromEntries(filenames.map(key => {
    const filepath = `./witnet/${key}.json`
    return [
      key,
      fs.existsSync(filepath) ? JSON.parse(fs.readFileSync(filepath)) : {},
    ]
  }))
}

function saveWitnetJsonFiles(data) {
  Object.entries(data).forEach(([key, obj]) => {
    const filepath = `./witnet/${key}.json`
    if (!fs.existsSync(filepath)) fs.writeFileSync(filepath, "{}")
    const json = merge(JSON.parse(fs.readFileSync(filepath)), obj)
    fs.writeFileSync(filepath, JSON.stringify(json, null, 4), { flag: "w+" })
  })
}

function supportedNetworks(ecosystem) {
  const networks = require("../../migrations/settings/networks.js").default
  return Object.fromEntries(
    Object.keys(constructorArgs)
      .sort()
      .filter(network => network.indexOf(":") >= 0 && (!ecosystem || network.startsWith(ecosystem.toLowerCase())))
      .map(network => {
        return [
          network,
          {
            mainnet: networks[network]?.mainnet || false,
            network_id: networks[network].network_id,
            port: networks[network].port,
            symbol: networks[network]?.symbol || "ETH",
            verified: networks[network]?.verify?.explorerUrl,
          },
        ]
      })
  )
}

function supportsNetwork(network) {
  return network && Object.keys(constructorArgs).includes(network.toLowerCase())
}

function traceHeader(header, color = colors.white, indent = "") {
  console.info(`${indent}┌─${"─".repeat(header.length)}─┐`)
  console.info(`${indent}│ ${color(header)} │`)
  console.info(`${indent}└─${"─".repeat(header.length)}─┘`)
}

function traceTable(records, options) {
  const stringify = (data, humanizers, index) => humanizers && humanizers[index] ? humanizers[index](data).toString() : data?.toString() ?? ""
  const reduceMax = (numbers) => numbers.reduce((curr, prev) => Math.max(curr, prev), 0)
  if (!options) options = {}
  const indent = options?.indent || ""
  const numColumns = reduceMax(records.map(record => record?.length || 1))
  const maxColumnWidth = options?.maxColumnWidth || 80
  const table = transpose(records, numColumns)
  options.widths = options?.widths || table.map((column, index) => {
    let maxWidth = reduceMax(column.map(field => colorstrip(stringify(field, options?.humanizers, index)).length))
    if (options?.headlines && options.headlines[index]) {
      maxWidth = Math.max(maxWidth, colorstrip(options.headlines[index].replaceAll(":", "")).length)
    }
    return Math.min(maxWidth, maxColumnWidth)
  })
  let headline = options.widths.map(maxWidth => "─".repeat(maxWidth))
  console.info(`${indent}┌─${headline.join("─┬─")}─┐`)
  if (options?.headlines) {
    headline = options.widths.map((maxWidth, index) => {
      const caption = options.headlines[index].replaceAll(":", "")
      const captionLength = colorstrip(caption).length
      return `${colors.white(caption)}${" ".repeat(maxWidth - captionLength)}`
    })
    console.info(`${indent}│ ${headline.join(" │ ")} │`)
    headline = options.widths.map(maxWidth => "─".repeat(maxWidth))
    console.info(`${indent}├─${headline.join("─┼─")}─┤`)
  }
  for (let i = 0; i < records.length; i++) {
    let line = ""
    for (let j = 0; j < numColumns; j++) {
      let data = table[j][i]
      let color
      if (options?.colors && options.colors[j]) {
        color = options.colors[j]
      } else {
        color = typeof data === "string"
          ? colors.green
          : (Number(data) === data && data % 1 !== 0 // is float number?
            ? colors.yellow
            : (x) => x
          )
      }
      data = stringify(data, options?.humanizers, j)
      if (colorstrip(data).length > maxColumnWidth) {
        while (colorstrip(data).length > maxColumnWidth - 3) {
          data = data.slice(0, -1)
        }
        data += "..."
      }
      const dataLength = colorstrip(data).length
      if (options?.headlines && options.headlines[j][0] === ":") {
        data = `${color(data)}${" ".repeat(options.widths[j] - dataLength)}`
      } else {
        data = `${" ".repeat(options.widths[j] - dataLength)}${color(data)}`
      }
      line += `│ ${data} `
    }
    console.info(`${indent}${line}│`)
  }
  headline = options.widths.map(maxWidth => "─".repeat(maxWidth))
  console.info(`${indent}└─${headline.join("─┴─")}─┘`)
}

function transpose(records, numColumns) {
  const columns = []
  for (let index = 0; index < numColumns; index++) {
    columns.push(records.map(row => row[index]))
  }
  return columns
}

function traceData(header, data, width, color) {
  process.stdout.write(header)
  if (color) process.stdout.write(color)
  for (let ix = 0; ix < data.length / width; ix++) {
    if (ix > 0) process.stdout.write(" ".repeat(header.length))
    process.stdout.write(data.slice(width * ix, width * (ix + 1)))
    process.stdout.write("\n")
  }
  if (color) process.stdout.write("\x1b[0m")
}

module.exports = {
  DEFAULT_BATCH_SIZE,
  DEFAULT_LIMIT,
  DEFAULT_SINCE,
  colors,
  chunks,
  deleteExtraFlags,
  extractFlagsFromArgs,
  extractOptionsFromArgs,
  flattenObject,
  orderKeys,
  traceData,
  traceHeader,
  getNetworkAddresses, getNetworkArtifacts, getNetworkConstructorArgs, getNetworkTagsFromString,
  supportedNetworks, supportsNetwork,
  importRadonAssets,
  readWitnetJsonFiles,
  saveWitnetJsonFiles,
  traceTable,
  commas,
  colorstrip,
  prompter,
}
