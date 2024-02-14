const ethUtils = require("ethereumjs-util")
const merge = require("lodash.merge")
const settings = require("../../settings")
const utils = require("../../src/utils")

const version = `${
  require("../../package").version
}-${
  require("child_process").execSync("git rev-parse HEAD").toString().trim().substring(0, 7)
}`

const WitnetDeployer = artifacts.require("WitnetDeployer")
const WitnetProxy = artifacts.require("WitnetProxy")

module.exports = async function (_, network, [, from, reporter]) {
  const targets = settings.getArtifacts(network)
  const specs = settings.getSpecs(network)

  const singletons = [
    "WitnetBytecodes",
    "WitnetRequestFactory",
    "WitnetRequestBoard",
    "WitnetPriceFeeds",
  ]

  // inject `reporter` within array of addresses as first initialization args
  specs.WitnetRequestBoard.mutables = merge({
    types: ["address[]"],
    values: [[reporter]],
  }, specs.WitnetRequestBoard.mutables
  )

  // Deploy/upgrade singleton proxies, if required
  for (const index in singletons) {
    const key = singletons[index]
    await deploy({
      network,
      specs,
      targets,
      key,
      from: utils.isDryRun(network) ? from : specs[key].from || from,
    })
  }
}

async function deploy (target) {
  const { from, key, network, specs, targets } = target

  const addresses = await utils.readJsonFromFile("./migrations/addresses.json")
  if (!addresses[network]) addresses[network] = {}

  const mutables = specs[key].mutables
  const proxy = artifacts.require(key)
  const proxySalt = specs[key].vanity
    ? "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(specs[key].vanity), 32).toString("hex")
    : "0x0"

  let proxyAddr = addresses[network][key] || addresses?.default[key] || ""
  if (utils.isNullAddress(proxyAddr) || (await web3.eth.getCode(proxyAddr)).length < 3) {
    utils.traceHeader(`Deploying '${key}'...`)
    console.info("  ", "> account:          ", from)
    console.info("  ", "> balance:          ", web3.utils.fromWei(await web3.eth.getBalance(from), "ether"), "ETH")
    const deployer = await WitnetDeployer.deployed()
    const impl = await artifacts.require(targets[key]).deployed()
    proxyAddr = await deployer.determineProxyAddr.call(proxySalt, { from })
    if ((await web3.eth.getCode(proxyAddr)).length < 3) {
      const initdata = mutables ? web3.eth.abi.encodeParameters(mutables.types, mutables.values) : "0x"
      if (initdata.length > 2) {
        console.info("  ", "> initialize types: ", mutables.types)
        console.info("  ", "> initialize params:", mutables.values)
      }
      const tx = await deployer.proxify(proxySalt, impl.address, initdata, { from })
      utils.traceTx(tx)
    } else {
      try {
        const oldImplAddr = await getProxyImplementation(from, proxyAddr)
        const oldImpl = await artifacts.require(targets[key]).at(oldImplAddr)
        const oldClass = await oldImpl.class.call({ from })
        const newClass = await impl.class.call({ from })
        if (oldClass !== newClass) {
          console.info(`Error: proxy address already taken ("${oldClass}" != "${newClass}")`)
          process.exit(1)
        } else {
          console.info("  ", `> recovered proxy address on class "${oldClass}" ;-)`)
        }
      } catch (ex) {
        console.info("Error: cannot check proxy recoverability:", ex)
      }
    }
    if ((await web3.eth.getCode(proxyAddr)).length > 3) {
      addresses[network][key] = proxyAddr
    } else {
      console.info(`Error: Contract was not deployed on expected address: ${proxyAddr}`)
      process.exit(1)
    }
    if (!utils.isDryRun(network)) {
      await utils.overwriteJsonFile("./migrations/addresses.json", addresses)
    }
  } else {
    const oldAddr = await getProxyImplementation(from, proxyAddr)
    const newImpl = await artifacts.require(targets[key]).deployed()
    if (oldAddr !== newImpl.address) {
      utils.traceHeader(`Upgrading '${key}'...`)
      const newVersion = await newImpl.version.call({ from })
      const color = newVersion === version ? "\x1b[1;97m" : "\x1b[93m"
      if (
        (process.argv.length >= 3 && process.argv[2].includes("--upgrade-all")) || (
          ["y", "yes"].includes((await
          utils.prompt(`   > Upgrade to ${color}${targets[key]} v${newVersion}\x1b[0m? (y/N) `)
          ).toLowerCase().trim())
        )
      ) {
        const initdata = mutables ? web3.eth.abi.encodeParameters(mutables.types, mutables.values) : "0x"
        if (initdata.length > 2) {
          console.info("  ", "> initialize types: ", mutables.types)
          console.info("  ", "> initialize params:", mutables.values)
        }
        const tx = await upgradeProxyTo(from, proxy, newImpl.address, initdata)
        utils.traceTx(tx)
      }
    } else {
      utils.traceHeader(`Skipped '${key}'`)
    }
  }
  proxy.address = proxyAddr
  const impl = await artifacts.require(targets[key]).at(proxy.address)
  console.info("  ", "> proxy address:    ", impl.address)
  console.info("  ", "> proxy codehash:   ", web3.utils.soliditySha3(await web3.eth.getCode(impl.address)))
  console.info("  ", "> proxy operator:   ", await impl.owner.call())
  console.info("  ", "> impl. address:    ", await getProxyImplementation(from, proxy.address))
  console.info("  ", "> impl. version:    ", await impl.version.call())
  console.info()
  return proxy
}

async function getProxyImplementation (from, proxyAddr) {
  const proxy = await WitnetProxy.at(proxyAddr)
  return await proxy.implementation.call({ from })
}

async function upgradeProxyTo (from, proxy, implAddr, initData) {
  const proxyContract = await WitnetProxy.at(proxy.address)
  return await proxyContract.upgradeTo(implAddr, initData, { from })
}
