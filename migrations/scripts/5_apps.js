const addresses = require("../witnet.addresses")
const ethUtils = require("ethereumjs-util")
const settings = require("../../settings")
const utils = require("../../src/utils")

const WitnetDeployer = artifacts.require("WitnetDeployer")

module.exports = async function (_, network, [,,, from]) {
  const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
  const ecosystem = utils.getRealmNetworkFromArgs()[0]
  network = network.split("-")[0]

  if (!addresses[ecosystem]) addresses[ecosystem] = {}
  if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

  const specs = settings.getSpecs(network);
  const targets = settings.getArtifacts(network);

  // Deploy the WitnetPriceFeeds oracle, if required
  {
    await deploy({
      from,
      ecosystem,
      network,
      targets,
      key: targets.WitnetPriceFeeds,
      libs: specs.WitnetPriceFeeds.libs,
      vanity: specs.WitnetPriceFeeds?.vanity || 0,
      immutables: specs.WitnetPriceFeeds.immutables,
      intrinsics: {
        types: ["address", "address"],
        values: [
        /* _operator */ from,
          /* _wrb      */ await determineProxyAddr(from, specs.WitnetRequestBoard?.vanity || 3),
        ],
      },
    })
    if (!isDryRun) utils.saveAddresses(addresses)
  }
  // Deploy the WitnetRandomness oracle, if required
  {
    await deploy({
      from,
      ecosystem,
      network,
      targets,
      key: targets.WitnetRandomness,
      libs: specs.WitnetRandomness?.libs,
      vanity: specs.WitnetRandomness?.vanity || 0,
      immutables: specs.WitnetRandomness?.immutables,
      intrinsics: {
        types: ["address", "address"],
        values: [
        /* _operator */ from,
          /* _wrb      */ await determineProxyAddr(from, specs.WitnetRequestBoard?.vanity || 3),
        ],
      },
    })
    if (!isDryRun) utils.saveAddresses(addresses)
  }
}

async function deploy (specs) {
  const { from, ecosystem, network, key, libs, intrinsics, immutables, targets, vanity } = specs
  const artifact = artifacts.require(key)
  const salt = vanity ? "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(vanity), 32).toString("hex") : "0x0"
  if (utils.isNullAddress(addresses[ecosystem][network][key])) {
    utils.traceHeader(`Deploying '${key}'...`)
    const deployer = await WitnetDeployer.deployed()
    let { types, values } = intrinsics
    if (immutables?.types) types = [...types, ...immutables.types]
    if (immutables?.values) values = [...values, ...immutables.values]
    const constructorArgs = web3.eth.abi.encodeParameters(types, values)
    if (constructorArgs.length > 2) {
      console.info("  ", "> constructor types:", types)
      console.info("  ", "> constructor args: ", constructorArgs.slice(2))
    }
    const coreBytecode = link(artifact.toJSON().bytecode, libs, targets)
    if (coreBytecode.indexOf("__") > -1) {
      console.info(bytecode)
      console.info("Cannot deploy due to some missing libs")
      process.exit(1)
    }
    const dappInitCode = coreBytecode + constructorArgs.slice(2)
    const dappAddr = await deployer.determineAddr.call(dappInitCode, salt, { from })
    console.info("  ", "> account:          ", from)
    console.info("  ", "> balance:          ", web3.utils.fromWei(await web3.eth.getBalance(from), "ether"), "ETH")
    const tx = await deployer.deploy(dappInitCode, salt, { from })
    utils.traceTx(tx)
    if ((await web3.eth.getCode(dappAddr)).length > 3) {
      addresses[ecosystem][network][key] = dappAddr
      // save/overwrite exportable abi file
      utils.saveJsonArtifact(key, artifact)
    } else {
      console.info(`Contract was not deployed on expected address: ${dappAddr}`)
      console.log(tx.receipt)
      process.exit(1)
    }
  } else {
    utils.traceHeader(`Skipped '${key}'`)
  }
  artifact.address = addresses[ecosystem][network][key]
  console.info("  ", "> contract address: ", artifact.address)
  console.info("  ", "> contract codehash:", web3.utils.soliditySha3(await web3.eth.getCode(artifact.address)))
  console.info()
  return artifact
}

async function determineProxyAddr (from, nonce) {
  const salt = nonce ? "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(nonce), 32).toString("hex") : "0x0"
  const deployer = await WitnetDeployer.deployed()
  const addr = await deployer.determineProxyAddr.call(salt, { from })
  return addr
}

function link (bytecode, libs, targets) {
  if (libs && Array.isArray(libs) && libs.length > 0) {
    for (index in libs) {
      const key = targets[libs[index]]
      const lib = artifacts.require(key)
      bytecode = bytecode.replaceAll(`__${key}${"_".repeat(38 - key.length)}`, lib.address.slice(2))
      console.info("  ", `> linked library:    ${key} => ${lib.address}`)
    }
  }
  return bytecode
}
