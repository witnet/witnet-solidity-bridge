// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../requests/WitnetRequest.sol";

contract WitnetRequestFactoryData {

    bytes32 internal constant _WITNET_REQUEST_SLOTHASH =
        /* keccak256("io.witnet.data.request") */
        0xbf9e297db5f64cdb81cd821e7ad085f56008e0c6100f4ebf5e41ef6649322034;

    bytes32 internal constant _WITNET_REQUEST_FACTORY_SLOTHASH =
        /* keccak256("io.witnet.data.request.factory") */
        0xfaf45a8ecd300851b566566df52ca7611b7a56d24a3449b86f4e21c71638e642;

    bytes32 internal constant _WITNET_REQUEST_TEMPLATE_SLOTHASH =
        /* keccak256("io.witnet.data.request.template") */
        0x50402db987be01ecf619cd3fb022cf52f861d188e7b779dd032a62d082276afb;

    struct Slot {
        address owner;
        address pendingOwner;
    }

    struct WitnetRequestSlot {
        /// Array of string arguments passed upon initialization.
        string[][] args;  
        /// Curator's address on settled requests.
        address curator;
        /// Radon RAD hash. 
        bytes32 radHash;
        /// Radon SLA hash.
        bytes32 slaHash;
        /// Parent WitnetRequestTemplate contract.
        WitnetRequestTemplate template;
    }

    struct WitnetRequestTemplateSlot {
        /// @notice Aggregator reducer hash.
        bytes32 aggregator;
        /// @notice Parent IWitnetRequestFactory from which this template was built.
        WitnetRequestFactory factory;
        /// Whether any of the sources is parameterized.
        bool parameterized;
        /// @notice Tally reducer hash.
        bytes32 tally;
        /// @notice Array of retrievals hashes passed upon construction.
        bytes32[] retrievals;
        /// @notice Result data type.
        WitnetV2.RadonDataTypes resultDataType;
        /// @notice Result max size or rank (if variable type).
        uint16 resultDataMaxSize; 
    }

    function __witnetRequestFactory()
        internal pure
        returns (Slot storage ptr)
    {
        assembly {
            ptr.slot := _WITNET_REQUEST_FACTORY_SLOTHASH
        }
    }

    function __witnetRequest()
        internal pure
        returns (WitnetRequestSlot storage ptr)
    {
        assembly {
            ptr.slot := _WITNET_REQUEST_SLOTHASH
        }
    }

    function __witnetRequestTemplate()
        internal pure
        returns (WitnetRequestTemplateSlot storage ptr)
    {
        assembly {
            ptr.slot := _WITNET_REQUEST_TEMPLATE_SLOTHASH
        }
    }
}