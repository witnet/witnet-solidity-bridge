const ethUtils = require("ethereumjs-util")
const { merge } = require("lodash")

const addresses = require("../witnet.addresses")
const settings = require("../witnet.settings")
const utils = require("../../scripts/utils")

const WitnetDeployer = artifacts.require("WitnetDeployer")
const WitnetProxy = artifacts.require("WitnetProxy")

module.exports = async function (_, network, [, from, reporter]) {
    const isDryRun = network === "test" || network.split("-")[1] === "fork" || network.split("-")[0] === "develop"
    const ecosystem = utils.getRealmNetworkFromArgs()[0]
    network = network.split("-")[0]

    if (!addresses[ecosystem]) addresses[ecosystem] = {}
    if (!addresses[ecosystem][network]) addresses[ecosystem][network] = {}

    const targets = merge(
        settings.artifacts.default,
        settings.artifacts[ecosystem],
        settings.artifacts[network]
    )
    const specs = merge(
        settings.specs.default,
        settings.specs[ecosystem],
        settings.specs[network],
    )
    const singletons = [
        "WitnetBytecodes",
        "WitnetRequestFactory",
        "WitnetRequestBoard",
    ]

    specs["WitnetRequestBoard"].mutables = merge({
            types: [ 'address[]', ],
            values: [ [ reporter, ], ], 
        }, specs["WitnetRequestBoard"].mutables
    )

    // Deploy/upgrade singleton proxies, if required
    for (index in singletons) {
        await deploy({
            from, ecosystem, network, specs, targets,
            key: singletons[index],
        });
        if (!isDryRun) {
            utils.saveAddresses(addresses);
        }
    }
}

async function deploy(target) {
    const { from, ecosystem, network, key, specs, targets } = target;
    
    const mutables = specs[key].mutables
    const proxy = artifacts.require(key)
    const proxy_salt = specs[key].vanity ? "0x" + ethUtils.setLengthLeft(ethUtils.toBuffer(specs[key].vanity), 32).toString("hex") : "0x0"
    
    if (utils.isNullAddress(addresses[ecosystem][network][key])) {
        utils.traceHeader(`Deploying '${key}'...`)
        console.info("  ", "> account:          ", from)
        console.info("  ", "> balance:          ", web3.utils.fromWei(await web3.eth.getBalance(from), 'ether'), "ETH")
        const deployer = await WitnetDeployer.deployed()
        const impl = await artifacts.require(targets[key]).deployed()
        const proxyAddr = await deployer.determineProxyAddr.call(proxy_salt, { from })
        if ((await web3.eth.getCode(proxyAddr)).length < 3) {
            const initdata = mutables ? web3.eth.abi.encodeParameters(mutables.types, mutables.values) : "0x"
            if (initdata.length > 2) {
                console.info("  ", "> initialize types: ", mutables.types)
                console.info("  ", "> initialize params:", mutables.values)
            }
            const tx = await deployer.proxify(proxy_salt, impl.address, initdata, { from })
            utils.traceTx(tx)
            // save/overwrite exportable abi file
            utils.saveJsonAbi(key, proxy.abi)
        } else {
            try {
                const oldImplAddr = await getProxyImplementation(from, proxyAddr)
                const oldImpl = await artifacts.require(targets[key]).at(oldImplAddr)
                const oldClass = await oldImpl.class.call({ from })
                const newClass = await impl.class.call({ from })
                if (oldClass !== newClass) {
                    console.info(`Error: proxy address already taken (\"${oldClass}\" != \"${newClass}\")`)
                    process.exit(1)
                } else {
                    console.info("  ", `> recovered proxy address on class \"${oldClass}\" ;-)`)
                } 
            } catch (ex) {
                console.info("Error: cannot check proxy recoverability:", ex)
            }
        }
        if ((await web3.eth.getCode(proxyAddr)).length > 3) {
            addresses[ecosystem][network][key] = proxyAddr
        } else {
            console.info(`Error: Contract was not deployed on expected address: ${proxyAddr}`)
            process.exit(1)
        }
    } else {
        const oldAddr = await getProxyImplementation(from, addresses[ecosystem][network][key])
        const oldImpl = await artifacts.require(targets[key]).at(oldAddr)
        const newImpl = await artifacts.require(targets[key]).deployed()
        if (oldAddr != newImpl.address) {
            utils.traceHeader(`Upgrading '${key}'...`)
            const oldVersion = await oldImpl.version.call({ from })
            const newVersion = await newImpl.version.call({ from })
            if(
                process.argv.length >= 3 && process.argv[2].includes("--upgrade-all") || ["y", "yes"].includes(
                    (await utils.prompt(`   > From v${oldVersion} to v${newVersion} ? [y / N]`)).toLowerCase().trim()
                )
            ) {
                const initdata = mutables ? web3.eth.abi.encodeParameters(mutables.types, mutables.values) : "0x"
                if (initdata.length > 2) {
                    console.info("  ", "> initialize types: ", mutables.types)
                    console.info("  ", "> initialize params:", mutables.values)
                }
                const tx = await upgradeProxyTo(from, proxy, newImpl.address, initdata)
                utils.traceTx(tx)
                // save/overwrite exportable abi file
                utils.saveJsonAbi(key, proxy.abi)
            }
        } else {
            utils.traceHeader(`Skipped '${key}'`)
        }
    }
    proxy.address = addresses[ecosystem][network][key]
    const impl = await artifacts.require(targets[key]).at(proxy.address)
    console.info("  ", "> proxy address:    ", impl.address)
    console.info("  ", "> proxy codehash:   ", web3.utils.soliditySha3(await web3.eth.getCode(impl.address)))
    console.info("  ", "> proxy operator:   ", await impl.owner.call())
    console.info("  ", "> impl. address:    ", await getProxyImplementation(from, proxy.address))
    console.info("  ", "> impl. version:    ", await impl.version.call())
    console.info()
    return proxy
}

async function getProxyImplementation(from, proxyAddr) {
    proxy = await WitnetProxy.at(proxyAddr)
    return await proxy.implementation.call({ from })
}

async function upgradeProxyTo(from, proxy, implAddr, initData) {
    proxy = await WitnetProxy.at(proxy.address)
    return await proxy.upgradeTo(implAddr, initData, { from })
}
