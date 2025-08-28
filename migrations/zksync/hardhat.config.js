require("dotenv").config()
require("@matterlabs/hardhat-zksync")
require("@matterlabs/hardhat-zksync-deploy")
require("@matterlabs/hardhat-zksync-upgradable")
require("@matterlabs/hardhat-zksync-verify")

module.exports = {
    deployerAccounts: {
        default: 1,
    },
    etherscan: {
        apiKey: {
            zksyncsepolia: process.env.ZKSYNC_ETHERSCAN_API_KEY,
        },
    },
    paths: {
        root: "../../",
        artifacts: "./migrations/zksync/artifacts",
        cache: "./migrations/zksync/cache",
        sources: "./contracts", 
    },
    networks: {
        hardhat: {
            zksync: true,
        },
        sepolia: {
            accounts: JSON.parse(process.env.ZKSYNC_PRIVATE_KEYS),
            chainId: 300,
            enableVerifyURL: true,
            ethNetwork: 'sepolia',
            url: 'https://sepolia.era.zksync.dev',
            zksync: true,
        }
    },
    solidity: {
        version: "0.8.26",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
            suppressedWarnings: [
                'txorigin',
            ],
            suppressedErrors: [
                'sendtransfer'
            ],
        },
    },
    sourcify: {
        enabled: true,
    },
    zksolc: {
        version: "1.5.11",
        settings: {
            codegen: "evmla",
            enableEraVMExtensions: false, // optional.  Enables Yul instructions available only for ZKsync system contracts and libraries
            forceEVMLA: false, // optional. Falls back to EVM legacy assembly if there is a bug with Yul
            libraries: {
                "contracts/data/WitOracleDataLib.sol": {
                    "WitOracleDataLib": "0xce45D4B8b31a96cF78cd0BF26b601108B8A3f889"
                },
                // "contracts/libs/WitOracleRadonEncodingLib.sol": {
                //   "WitOracleRadonEncodingLib": "0xe7832c802417076B795E8C3785B610B03A6d50F6"
                // },
                "contracts/libs/WitOracleResultStatusLib.sol": {
                    "WitOracleResultStatusLib": "0x12717Bdcfd40BD7Fa9216E979AE846f076B38F0a"
                },
                // "contracts/data/WitPriceFeedsDataLib.sol": {
                //     "WitPriceFeedsDataLib": "0x3976C352e3474e9BF9c1229D1c3aAE8AA7F1c600"
                // },
            },
            missingLibrariesPath: "./migrations/zksync/missingLibraryDependencies.json", // optional. This path serves as a cache that stores all the libraries that are missing or have dependencies on other libraries. A `hardhat-zksync-deploy` plugin uses this cache later to compile and deploy the libraries, especially when the `deploy-zksync:libraries` task is executed
            optimizer: {
                enabled: true,
                mode: 'z', // optional. 3 by default, z to optimize bytecode size
                fallback_to_optimizing_for_size: false, // optional. Try to recompile with optimizer mode "z" if the bytecode is too large
            },
            suppressedWarnings: [
                'txorigin',
            ],
            suppressedErrors: [
                'sendtransfer'
            ],
            contractsToCompile: [
                // "WitnetProxy",
                "WitOracleTrustableZkSync",
                // "WitOracleRadonRegistryUpgradableZkSync",
                // "WitPriceFeedsUpgradableZkSync",
                // "WitRandomnessV3",
            ],
        },
    }
}