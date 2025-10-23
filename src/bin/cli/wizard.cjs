const fs = require("fs")
const inquirer = require("inquirer")
const path = require("path")

const { supportsNetwork, supportedEcosystems, supportedNetworks } = require("@witnet/solidity").default

const helpers = require("../helpers.js")

const MODULE_WITNET_PATH = process.env.WITNET_SOLIDITY_MODULE_PATH || "node_modules/witnet-solidity/witnet"

const camelizeDashedString = (str) => str.split("-").map(part => capitalizeFirstLetter(part)).join("")
const capitalizeFirstLetter = (str) => str.charAt(0).toUpperCase() + str.slice(1).toLowerCase()

module.exports = async function (flags = {}) {
  const network = flags?.network
  if (network && !supportsNetwork(network)) {
    throw new Error(`Unsupported network "${network}"`)
  }
  let contractPath = "contracts/"
  let contractName = flags?.contract || ""
  let isFirstMockup = true
  let namedByUser = false
  if (contractName !== "") {
    if (contractName.indexOf("/") > -1) {
      contractPath = contractName.slice(0, contractName.lastIndexOf("/"))
      contractName = contractName.slice(contractName.lastIndexOf("/") + 1)
    }
    if (fs.existsSync(contractPath + contractName)) {
      console.info("Sorry, output file already exists:", contractName)
      process.exit(1)
    } else if (!fs.existsSync(contractPath)) {
      fs.mkdirSync(contractPath)
    }
    if (contractName.endsWith(".sol")) contractName = contractName.slice(0, -4)
    contractName = camelizeDashedString(contractName)
    namedByUser = true
  }
  if (contractName === "") {
    const basename = `WitOracle${camelizeDashedString(path.basename(process.cwd()))}`
    if (!fs.existsSync(contractPath)) {
      fs.mkdirSync(contractPath)
    }
    const files = fs.readdirSync(contractPath).filter(filename => filename.startsWith(basename))
    contractName = `${basename}${files.length + 1}`
    isFirstMockup = files.length === 0
  }
  let answers = {
    ...await inquirer.prompt([{
      type: "rawlist",
      name: "usage",
      message: `What will ${isFirstMockup ? "your first" : (namedByUser ? `the ${contractName}` : "your next")
      } Solidity contract be using the Wit/Oracle for?`,
      choices: [
        "Randomness => unmalleable source of entropy.",
        "Price feeds => based on multiple, reliable and public data sources.",
        "Public data => retrieved from a single or multiple providers on the Internet.",
      ],
    }]),
  }
  const appKind = answers.usage.split(" ")[0]
  switch (appKind) {
    case "Randomness": {
      answers = {
        ...await inquirer.prompt({
          type: "list",
          name: "randomness",
          message: "Would you rather rely on the WitRandomness appliance or handle resolution of randomness requests at a lower level?",
          choices: [
            "Yes => use the WitRandomness appliance (randomize results need to be polled).",
            "No  => I know how to handle randomness request callbacks, attend eventual faulty requests and protect against front-run attacks.",
          ],
        }),
        ...answers,
      }
      break
    }
    case "Public": {
      answers = {
        ...await inquirer.prompt({
          type: "list",
          name: "dynamic",
          message: "Will the underlying data sources or parameters vary in time",
          choices: [
            "Yes => either the data sources, or some request parameters, will vary in time.",
            "No  => the data sources and parameters will remain constant.",
          ],
        }),
        ...answers,
      }
      if (answers?.dynamic.split(" ")[0] === "Yes") {
        answers = {
          ...await inquirer.prompt({
            type: "list",
            name: "parameterized",
            message: "Will your contract have to deal with data request parameters?",
            choices: [
              "Yes => my contract will have to generate actual parameter values onchain.",
              "No => Witnet-compliant data request bytecode will be provided by some Externally Owned Account.",
            ],
          }),
          ...answers,
        }
      }
      if (answers?.dynamic.split(" ")[0] === "No" || answers?.parameterized.split(" ")[0] === "Yes") {
        answers = {
          ...await inquirer.prompt({
            type: "list",
            name: "callbacks",
            message: "How would you like your contract to fetch data provided from the Wit/Oracle?",
            choices: [
              "Asynchronously => my contract will eventually read the result from the WitOracle contract.",
              "Synchronously => my contract is to be called as soon as data is reported from the Wit/Oracle.",
            ],
          }),
          ...answers,
        }
      }
      break
    }
  }
  // console.info()
  if (
    answers?.randomness?.split(" ")[0] === "No" ||
        answers?.callbacks?.split(" ")[0] === "Synchronously" ||
        answers?.parameterized?.split(" ")[0] === "No"
  ) {
    let callbackGasLimit
    do {
      callbackGasLimit = parseInt((await inquirer.prompt({
        type: "number",
        name: "callbackGasLimit",
        message: "Please, specify the maximum gas that you expect your Witnet-callback methods to consume:",
        default: 250000,
      })).callbackGasLimit)
    } while (!callbackGasLimit)
    answers = { callbackGasLimit, ...answers }
  }
  let importWitnetMocks = ""
  if (
    appKind === "Randomness" ||
        appKind === "Price" ||
        answers?.parameterized?.split(" ")[0] === "No"
  ) {
    // answers = {
    //     ...await inquirer.prompt({
    //         type: "confirm",
    //         name: "includeMocks",
    //         message: "Do you intend to include your new contract within unitary Solidity tests?",
    //         default: false,
    //     }),
    //     ...answers,
    // }
    answers.includeMocks = false
    if (!answers.includeMocks) {
      const artifact = (appKind === "Price"
        ? "apps.WitPriceFeeds"
        : answers?.randomness?.split(" ")[0] === "Yes"
          ? "apps.WitRandomnessV2"
          : "core.WitOracle"
      )
      const findings = []
      if (!network) {
        const choices = supportedEcosystems().map(e => e.toUpperCase())
        answers = {
          ...await inquirer.prompt({
            type: "checkbox",
            name: "ecosystems",
            message: "Please, select the ecosystem(s) where you intend to deploy this new contract:",
            choices,
            pageSize: 32,
            loop: true,
            validate: (ans) => { return (ans.length > 0) },
          }),
          ...answers,
        }
        answers?.ecosystems.forEach(ecosystem => {
          Object.keys(supportedNetworks(ecosystem)).forEach(network => {
            const addrs = helpers.flattenObject(helpers.getNetworkAddresses(network))
            const artifactAddr = addrs[artifact]
            if (artifactAddr && !findings.includes(artifactAddr)) {
              findings.push(artifactAddr)
            }
          })
        })
      } else {
        const addrs = helpers.flattenObject(helpers.getNetworkAddresses(network))
        if (addrs[artifact]) {
          findings.push(addrs[artifact])
        }
      }
      if (findings.length === 1) {
        answers = {
          ...answers,
          witnetAddress: findings[0],
        }
      } else if (findings.length === 0) {
        throw Error(`Sorry, required ${artifact} contract is not available on selected ecosystems: ${answers?.ecosystems}`)
      }
    } else {
      importWitnetMocks = "\nimport \"@witnet/solidity/contracts/mocks/WitMockedOracle.sol\";"
    }
  }

  let baseFeeOverhead = 5 // 5%
  answers = {
    ...await inquirer.prompt([{
      type: "rawlist",
      name: "overhead",
      message: "How much extra fee would you pay as to to prevent EVM gas price variations affecting queries resolution time?",
      choices: [
        "Average (+15%)",
        "Generous (+30%)",
        "Precautious (+50%)",
        "Stingy (+5%)",
      ],
    }]),
    ...answers,
  }
  switch (answers.overhead.split(" ")[0].toLowerCase()) {
    case "average": baseFeeOverhead = 15; break
    case "generous": baseFeeOverhead = 30; break
    case "precautious": baseFeeOverhead = 50; break
  }

  let constructorParams = ""
  let witnetAddress = ""
  let templateFile = `${MODULE_WITNET_PATH}/contracts/`
  switch (appKind) {
    case "Randomness": {
      if (answers?.randomness?.split(" ")[0] === "Yes") {
        if (!answers?.witnetAddress) {
          constructorParams = "WitRandomness _witnetRandomness"
          witnetAddress = "_witnetRandomness"
        } else {
          witnetAddress = `WitRandomness(${answers.witnetAddress})`
        }
        templateFile += "_UsingRandomness.tsol"
      } else {
        if (!answers?.witnetAddress) {
          constructorParams = "WitOracle _witOracle"
          witnetAddress = "_witOracle"
        } else {
          witnetAddress = `WitOracle(${answers.witnetAddress})`
        }
        templateFile += "_RandomnessRequestConsumer.tsol"
      }
      break
    }
    case "Price": {
      if (!answers?.witnetAddress) {
        constructorParams = "WitPriceFeeds _witnetPriceFeeds"
        witnetAddress = "_witnetPriceFeeds"
      } else {
        witnetAddress = `WitPriceFeeds(${answers.witnetAddress})`
      }
      templateFile += "_UsingPriceFeeds.tsol"
      break
    }
    case "Public": {
      if (answers?.dynamic.split(" ")[0] === "Yes") {
        if (answers.parameterized.split(" ")[0] === "Yes") {
          constructorParams = "WitOracleRadonRequestTemplate _witOracleRequestTemplate"
          witnetAddress = "_witOracleRequestTemplate"
          templateFile += (answers?.callbacks.split(" ")[0] === "Synchronously"
            ? "_RequestTemplateConsumer.tsol"
            : "_UsingRequestTemplate.tsol"
          )
        } else {
          if (!answers?.witnetAddress) {
            constructorParams = "WitOracle _witOracle"
            witnetAddress = "_witOracle"
          } else {
            witnetAddress = `WitOracle(${answers.witnetAddress})`
          }
          templateFile += "_Consumer.tsol"
        }
      } else {
        constructorParams = "WitOracleRequest _witOracleRequest"
        witnetAddress = "_witOracleRequest"
        templateFile += (answers?.callbacks.split(" ")[0] === "Synchronously"
          ? "_RequestConsumer.tsol"
          : "_UsingRequest.tsol"
        )
      }
      break
    }
  }

  const solidity = fs.readFileSync(templateFile, "utf-8")
    .replaceAll("$_importWitnetMocks", importWitnetMocks)
    .replaceAll("$_contractName", contractName)
    .replaceAll("$_constructorParams", constructorParams)
    .replaceAll("$_witnetAddress", witnetAddress)
    .replaceAll("$_baseFeeOverhead", baseFeeOverhead)
    .replaceAll("$_callbackGasLimit", answers.callbackGasLimit)

  const solidityPathFileName = `${contractPath}${contractName}.sol`
  fs.writeFileSync(solidityPathFileName, solidity)
  console.info()
  console.info("Awesome! Your new contract was just created here:")
  console.info(`\x1b[35m${contractPath}\x1b[1;35m${contractName}.sol\x1b[0m`)
}
