const ethUtils = require("ethereumjs-util")
const { merge } = require("lodash")

const addresses = require("../witnet.addresses")
const settings = require("../witnet.settings")
const utils = require("../../scripts/utils")
const version = `${
    require("../../package").version
  }-${
    require("child_process").execSync("git rev-parse HEAD").toString().trim().substring(0, 7)
  }`

const WitnetDeployer = artifacts.require("WitnetDeployer")

module.exports = async function (_, network, [, from]) {
    const isDryRun = false // network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
    const ecosystem = utils.getRealmNetworkFromArgs()[0]
    network = network.split("-")[0]

    if (!addresses[ecosystem]) addresses[ecosystem] = {}
    if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

    const specs = merge(
        settings.specs.default,
        settings.specs[ecosystem],
        settings.specs[network],
    )
    const targets = merge(
        settings.artifacts.default,
        settings.artifacts[ecosystem],
        settings.artifacts[network]
    )

    // Deploy/upgrade WitnetBytecodes target implementation, if required
    {
        await deploy({
            from, ecosystem, network, targets,
            key: targets.WitnetBytecodes, 
            libs: specs.WitnetBytecodes.libs,
            immutables: specs.WitnetBytecodes.immutables,
            intrinsics: { types: [ 'bool', 'bytes32' ], values: [ 
                /* _upgradable */ true, 
                /* _versionTag */ utils.fromAscii(version)
            ]},
        });
        if (!isDryRun) {
            utils.saveAddresses(addresses);
        }
    }
    // Deploy/upgrade WitnetRequestFactory target implementation, if required
    {
        await deploy({
            from, ecosystem, network, targets,
            key: targets.WitnetRequestFactory, 
            libs: specs.WitnetRequestFactory.libs,
            immutables: specs.WitnetRequestFactory.immutables,
            intrinsics: { types: [ 'address', 'bool', 'bytes32' ], values: [ 
                /* _registry   */ await determineProxyAddr(from, specs.WitnetBytecodes?.vanity || 1), 
                /* _upgradable */ true, 
                /* _versionTag */ utils.fromAscii(version),
            ]},
        });
        if (!isDryRun) {
            utils.saveAddresses(addresses);
        }
    }
    // Deploy/upgrade WitnetRequestBoard target implementation, if required
    {
        await deploy({
            from, ecosystem, network, targets,
            key: targets.WitnetRequestBoard, 
            libs: specs.WitnetRequestBoard.libs,
            immutables: specs.WitnetRequestBoard.immutables,
            intrinsics: { types: [ 'address', 'bool', 'bytes32' ], values: [ 
                /* _registry   */ await determineProxyAddr(from, specs.WitnetRequestFactory?.vanity || 2), 
                /* _upgradable */ true, 
                /* _versionTag */ utils.fromAscii(version),
            ]},
        });
        if (!isDryRun) {
            utils.saveAddresses(addresses);
        }
    }
}

async function deploy(specs) {
    const { from, ecosystem, network, key, libs, intrinsics, immutables, targets } = specs;
    const contract = artifacts.require(key)
    if (utils.isNullAddress(addresses[ecosystem][network][key])) {
        utils.traceHeader(`Deploying '${key}'...`)
        console.info("  ", "> account:          ", from)
        console.info("  ", "> balance:          ", web3.utils.fromWei(await web3.eth.getBalance(from), 'ether'), "ETH")
        const deployer = await WitnetDeployer.deployed()
        let { types, values } = intrinsics
        if (immutables?.types) types = [ ...types, ...immutables.types ]
        if (immutables?.values) values = [ ...values, ...immutables.values ]
        const constructorArgs = web3.eth.abi.encodeParameters(types, values)
        if (constructorArgs.length > 2) {
            console.info("  ", "> constructor types:", types)
            console.info("  ", "> constructor args: ", constructorArgs.slice(2))
        }
        const coreBytecode = link(contract.toJSON().bytecode, libs, targets)
        if (coreBytecode.indexOf("__") > -1) {
            console.info(bytecode)
            console.info("Cannot deploy due to some missing libs")
            process.exit(1)
        }
        const coreInitCode = coreBytecode + constructorArgs.slice(2)
        const coreAddr = await deployer.determineAddr.call(coreInitCode, "0x0", { from })
        const tx = await deployer.deploy(coreInitCode, "0x0", { from })
        console.info("  ", "> transaction hash: ", tx.receipt.transactionHash)
        console.info("  ", "> gas used:         ", tx.receipt.gasUsed.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ","))
        console.info("  ", "> gas price:        ", tx.receipt.effectiveGasPrice / 10 ** 9, "gwei")
        console.info("  ", "> total cost:       ", web3.utils.fromWei(BigInt(tx.receipt.gasUsed * tx.receipt.effectiveGasPrice).toString(), 'ether'), "ETH")
        if ((await web3.eth.getCode(coreAddr)).length > 3) {
            addresses[ecosystem][network][key] = coreAddr
        } else {
            console.info(`Contract was not deployed on expected address: ${coreAddr}`)
            process.exit(1)
        }
    } else {
        utils.traceHeader(`Deployed '${key}'`)
    }
    contract.address = addresses[ecosystem][network][key]
    console.info("  ", "> contract address: ", contract.address)
    console.info("  ", "> contract codehash:", web3.utils.soliditySha3(await web3.eth.getCode(contract.address)))
    console.info()
    return contract
}

async function determineProxyAddr(from, nonce) {
    const salt = nonce ? "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(nonce), 32).toString("hex") : "0x0"
    const deployer = await WitnetDeployer.deployed()
    return await deployer.determineProxyAddr.call(salt, { from })
}

function link(bytecode, libs, targets) {
    if (libs && Array.isArray(libs) && libs.length > 0) {
        for (index in libs) {
            const key = targets[libs[index]]
            const lib = artifacts.require(key)
            bytecode = bytecode.replaceAll(`__${key}${"_".repeat(38-key.length)}`, lib.address.slice(2))
            console.info("  ", `> linked library:    ${key} => ${lib.address}`)
        }
    }
    return bytecode
}