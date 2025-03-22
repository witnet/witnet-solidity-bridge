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
        deployPaths: ["./migrations/zksync/deployments"],
        deploymentPaths: ["./migrations/zksync/deployments"],
        deployments: "./migrations/zksync/deployments",
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
            // verifyURL: 'https://sepolia.explorer.zksync.io/api',
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
            evmVersion: "paris",
            suppressedWarnings: [
                'AssemblyCreate',
                'TxOrigin',
            ],
            suppressedErrors: [
                'SendTransfer'
            ],
        },
    },
    sourcify: {
        enabled: true,
    },
    zksolc: {
        version: "latest",
        settings: {
            codegen: "evmla",
            deployPaths: ["./migrations/zksync/deployments"],
            deploymentPaths: ["./migrations/zksync/deployments"],
            enableEraVMExtensions: false, // optional.  Enables Yul instructions available only for ZKsync system contracts and libraries
            forceEVMLA: false, // optional. Falls back to EVM legacy assembly if there is a bug with Yul
            libraries: {
                "contracts/data/WitOracleDataLib.sol": {
                    "WitOracleDataLib": "0xC4778500c689fb72339187E2e82D41b967D5AF19"
                },
                "contracts/libs/WitOracleRadonEncodingLib.sol": {
                  "WitOracleRadonEncodingLib": "0x2Ef06D1132A9ae147EDc4Dd4EbF99fB872BCA18f"
                },
                "contracts/libs/WitOracleResultStatusLib.sol": {
                    "WitOracleResultStatusLib": "0x8139eCe42e69817217B7A85a5746C51633343DCF"
                },
                "contracts/data/WitPriceFeedsDataLib.sol": {
                    "WitPriceFeedsDataLib": "0x3976C352e3474e9BF9c1229D1c3aAE8AA7F1c600"
                },
            },
            missingLibrariesPath: "./migrations/zksync/missingLibraryDependencies.json", // optional. This path serves as a cache that stores all the libraries that are missing or have dependencies on other libraries. A `hardhat-zksync-deploy` plugin uses this cache later to compile and deploy the libraries, especially when the `deploy-zksync:libraries` task is executed
            optimizer: {
                enabled: true,
                mode: 'z', // optional. 3 by default, z to optimize bytecode size
                fallback_to_optimizing_for_size: false, // optional. Try to recompile with optimizer mode "z" if the bytecode is too large
            },
            suppressedWarnings: [
                // 'AssemblyCreate',
                'TxOrigin',
            ],
            suppressedErrors: [
                'SendTransfer'
            ],
            contractsToCompile: [
                "WitnetProxy",
                "WitOracleTrustableZkSync",
                "WitOracleRadonRegistryUpgradableZkSync",
                // // "WitPriceFeedsUpgradableZkSync",
                "WitRandomnessV21",
            ],
        },
    }
}