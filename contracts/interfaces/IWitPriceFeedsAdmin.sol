// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import {IWitPriceFeedsTypes} from "./IWitPriceFeedsTypes.sol";
import {Witnet} from "../libs/Witnet.sol";

interface IWitPriceFeedsAdmin {

    function acceptOwnership() external;
    function owner() external view returns (address);
    function pendingOwner() external returns (address);
    function removePriceFeed(string calldata, bool) external returns (bytes4);
    
    function settleConsumer(address) external;
    
    function settlePriceFeedMapper(
            string calldata caption, 
            int8 exponent, 
            IWitPriceFeedsTypes.Mappers mapper, 
            string[] calldata deps
        ) external returns (bytes4);
    
    function settlePriceFeedOracle(
            string calldata caption, 
            int8 exponent, 
            IWitPriceFeedsTypes.Oracles oracle, 
            address target, 
            bytes32 sources
        ) external returns (bytes4);
    
    function settlePriceFeedRadonBytecode(
            string calldata caption, 
            int8 exponent, 
            bytes calldata radonBytecode
        ) external returns (bytes4);

    function settlePriceFeedRadonHash(
            string calldata caption, 
            int8 exponent, 
            Witnet.RadonHash radonHash
        ) external returns (bytes4);

    function settlePriceFeedUpdateConditions(
            string calldata caption, 
            IWitPriceFeedsTypes.PriceUpdateConditions calldata conditions
        ) external;

    function transferOwnership(address) external;
}
