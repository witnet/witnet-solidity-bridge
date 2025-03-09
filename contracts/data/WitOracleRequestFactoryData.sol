// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../WitOracleRequest.sol";
import "../WitOracleRequestTemplate.sol";

contract WitOracleRequestFactoryData {

    bytes32 internal constant _WIT_ORACLE_REQUEST_SLOTHASH =
        /* keccak256("io.witnet.data.request") */
        0xbf9e297db5f64cdb81cd821e7ad085f56008e0c6100f4ebf5e41ef6649322034;

    bytes32 internal constant _WIT_ORACLE_REQUEST_FACTORY_SLOTHASH =
        /* keccak256("io.witnet.data.request.factory") */
        0xfaf45a8ecd300851b566566df52ca7611b7a56d24a3449b86f4e21c71638e642;

    bytes32 internal constant _WIT_ORACLE_REQUEST_TEMPLATE_SLOTHASH =
        /* keccak256("io.witnet.data.request.template") */
        0x50402db987be01ecf619cd3fb022cf52f861d188e7b779dd032a62d082276afb;

    struct WitOracleRequestFactoryStorage {
        address owner;
        address pendingOwner;
    }

    struct WitOracleRequestStorage {
        /// Radon RAD hash.
        Witnet.RadonHash radHash;
        // /// Array of string arguments passed upon initialization.
        // string[][] args;
    }

    struct WitOracleRequestTemplateStorage {
        /// @notice Array of retrievals hashes passed upon construction.
        bytes32[] retrieveHashes;
        /// @notice Aggregator reduce hash.
        bytes16 aggregateReduceHash;
        /// @notice Tally reduce hash.
        bytes16 tallyReduceHash;
    }

    function __witOracleRequestFactory()
        internal pure
        returns (WitOracleRequestFactoryStorage storage ptr)
    {
        assembly {
            ptr.slot := _WIT_ORACLE_REQUEST_FACTORY_SLOTHASH
        }
    }

    function __witOracleRequest()
        internal pure
        returns (WitOracleRequestStorage storage ptr)
    {
        assembly {
            ptr.slot := _WIT_ORACLE_REQUEST_SLOTHASH
        }
    }

    function __witOracleRequestTemplate()
        internal pure
        returns (WitOracleRequestTemplateStorage storage ptr)
    {
        assembly {
            ptr.slot := _WIT_ORACLE_REQUEST_TEMPLATE_SLOTHASH
        }
    }
}