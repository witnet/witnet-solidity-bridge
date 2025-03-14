// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "ado-contracts/contracts/interfaces/IERC2362.sol";

import "./interfaces/legacy/IWitPriceFeedsLegacy.sol";
import "./interfaces/legacy/IWitPriceFeedsLegacyAdmin.sol";
import "./interfaces/legacy/IWitPriceFeedsLegacySolverFactory.sol";

/// @title WitPriceFeedsLegacy: Price Feeds live repository reliant on the Wit/Oracle blockchain, up to V2.0. 
/// @author The Witnet Foundation.
abstract contract WitPriceFeedsLegacy
    is
        IERC2362,
        IWitPriceFeedsLegacy,
        IWitPriceFeedsLegacyAdmin,
        IWitPriceFeedsLegacySolverFactory,
        IWitOracleAppliance
{
    Witnet.RadonDataTypes immutable public override dataType = Witnet.RadonDataTypes.Integer;
    bytes32 immutable internal __prefix = "Price-";

    function prefix() virtual override external view returns (string memory) {
        return Witnet.toString(__prefix);
    }
    
    function specs() virtual override external pure returns (bytes4) {
        return (
            type(IERC2362).interfaceId
                ^ type(IWitOracleAppliance).interfaceId
                ^ type(IWitPriceFeedsLegacy).interfaceId
                ^ type(IWitPriceFeedsLegacyAdmin).interfaceId
                ^ type(IWitPriceFeedsLegacySolverFactory).interfaceId
        );
    }
}
