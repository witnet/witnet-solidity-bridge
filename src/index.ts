export * from "./lib/types.js"
export * from "./lib/wrappers.js"

export * as ethers from "ethers"
export * as utils from "./lib/utils.js"

import { createRequire } from "module";
const require = createRequire(import.meta.url);

export const ABIs: any = {
    WitAppliance:
        require("../../artifacts/contracts/interfaces/IWitAppliance.sol/IWitAppliance.json").abi,
    WitOracle:
        require("../../artifacts/contracts/WitOracle.sol/WitOracle.json").abi,
    WitOracleConsumer:
        require("../../artifacts/contracts/interfaces/IWitOracleConsumer.sol/IWitOracleConsumer.json").abi,
    WitOracleRadonRegistry:
        require("../../artifacts/contracts/WitOracleRadonRegistry.sol/WitOracleRadonRegistry.json").abi,
    WitOracleRadonRequestFactory:
        require("../../artifacts/contracts/WitOracleRadonRequestFactory.sol/WitOracleRadonRequestFactory.json").abi,
    WitOracleRadonRequestModal:
        require("../../artifacts/contracts/interfaces/IWitOracleRadonRequestModal.sol/IWitOracleRadonRequestModal.json").abi,
    WitOracleRadonRequestTemplate:
        require("../../artifacts/contracts/interfaces/IWitOracleRadonRequestTemplate.sol/IWitOracleRadonRequestTemplate.json").abi,
    WitPriceFeeds:
        require("../../artifacts/contracts/WitPriceFeeds.sol/WitPriceFeeds.json").abi,
    WitPriceFeedsLegacy:
        require("../../artifacts/contracts/WitPriceFeedsLegacy.sol/WitPriceFeedsLegacy.json").abi,
    WitRandomnessV2:
        require("../../artifacts/contracts/WitRandomnessLegacy.sol/WitRandomnessLegacy.json").abi,
    WitRandomnessV3:
        require("../../artifacts/contracts/WitRandomness.sol/WitRandomness.json").abi,
    WitnetUpgradableBase:
        require("../../artifacts/contracts/core/WitnetUpgradableBase.sol/WitnetUpgradableBase.json").abi,
}
