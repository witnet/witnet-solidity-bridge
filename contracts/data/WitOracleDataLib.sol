// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../WitOracleRadonRegistry.sol";
import "../libs/Witnet.sol";

/// @title Witnet Request Board base data model library
/// @author The Witnet Foundation.
library WitOracleDataLib {  

    using Witnet for Witnet.QueryRequest;

    bytes32 internal constant _WIT_ORACLE_DATA_SLOTHASH =
        /* keccak256("io.witnet.boards.data") */
        0xf595240b351bc8f951c2f53b26f4e78c32cb62122cf76c19b7fdda7d4968e183;

    struct Storage {
        uint256 nonce;
        mapping (uint => Witnet.Query) queries;
        mapping (address => bool) reporters;
    }

    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    /// Returns storage pointer to contents of 'WitnetBoardState' struct.
    function data() internal pure returns (Storage storage _ptr)
    {
        assembly {
            _ptr.slot := _WIT_ORACLE_DATA_SLOTHASH
        }
    }

    function isReporter(address addr) internal view returns (bool) {
        return data().reporters[addr];
    }

    /// Gets query storage by query id.
    function seekQuery(uint256 _queryId) internal view returns (Witnet.Query storage) {
      return data().queries[_queryId];
    }

    /// Gets the Witnet.QueryRequest part of a given query.
    function seekQueryRequest(uint256 _queryId) internal view returns (Witnet.QueryRequest storage) {
        return data().queries[_queryId].request;
    }   

    /// Gets the Witnet.Result part of a given query.
    function seekQueryResponse(uint256 _queryId) internal view returns (Witnet.QueryResponse storage) {
        return data().queries[_queryId].response;
    }

    function seekQueryStatus(uint256 queryId) internal view returns (Witnet.QueryStatus) {
        Witnet.Query storage __query = data().queries[queryId];
        if (__query.response.resultTimestamp != 0) {
            if (block.number >= __query.response.finality) {
                return Witnet.QueryStatus.Finalized;
            } else {
                return Witnet.QueryStatus.Reported;
            }
        } else if (__query.request.requester != address(0)) {
            return Witnet.QueryStatus.Posted;
        } else {
            return Witnet.QueryStatus.Unknown;
        }
    }

    function seekQueryResponseStatus(uint256 queryId) internal view returns (Witnet.QueryResponseStatus) {
        Witnet.QueryStatus _queryStatus = seekQueryStatus(queryId);
        if (_queryStatus == Witnet.QueryStatus.Finalized) {
            bytes storage __cborValues = data().queries[queryId].response.resultCborBytes;
            if (__cborValues.length > 0) {
                // determine whether stored result is an error by peeking the first byte
                return (__cborValues[0] == bytes1(0xd8)
                    ? Witnet.QueryResponseStatus.Error 
                    : Witnet.QueryResponseStatus.Ready
                );
            } else {
                // the result is final but delivered to the requesting address
                return Witnet.QueryResponseStatus.Delivered;
            }
        } else if (_queryStatus == Witnet.QueryStatus.Posted) {
            return Witnet.QueryResponseStatus.Awaiting;
        } else if (_queryStatus == Witnet.QueryStatus.Reported) {
            return Witnet.QueryResponseStatus.Finalizing;
        } else {
            return Witnet.QueryResponseStatus.Void;
        }
    }

    // ================================================================================================================
    // --- Public functions -------------------------------------------------------------------------------------------

    function extractWitnetDataRequests(WitOracleRadonRegistry registry, uint256[] calldata queryIds)
        public view
        returns (bytes[] memory bytecodes)
    {
        bytecodes = new bytes[](queryIds.length);
        for (uint _ix = 0; _ix < queryIds.length; _ix ++) {
            if (seekQueryStatus(queryIds[_ix]) != Witnet.QueryStatus.Unknown) {
                Witnet.QueryRequest storage __request = data().queries[queryIds[_ix]].request;
                if (__request.witnetRAD != bytes32(0)) {
                    bytecodes[_ix] = registry.bytecodeOf(
                        __request.witnetRAD,
                        __request.witnetSLA
                    );
                } else {
                    bytecodes[_ix] = registry.bytecodeOf(
                        __request.witnetBytecode,
                        __request.witnetSLA 
                    );
                }
            }
        }
    }

    function notInStatusRevertMessage(Witnet.QueryStatus self) public pure returns (string memory) {
        if (self == Witnet.QueryStatus.Posted) {
            return "query not in Posted status";
        } else if (self == Witnet.QueryStatus.Reported) {
            return "query not in Reported status";
        } else if (self == Witnet.QueryStatus.Finalized) {
            return "query not in Finalized status";
        } else {
            return "bad mood";
        }
    }
}
