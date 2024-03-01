// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../WitnetRequestBytecodes.sol";
import "../libs/WitnetV2.sol";

/// @title Witnet Request Board base data model library
/// @author The Witnet Foundation.
library WitnetOracleDataLib {  

    using WitnetV2 for WitnetV2.Request;

    bytes32 internal constant _WITNET_ORACLE_DATA_SLOTHASH =
        /* keccak256("io.witnet.boards.data") */
        0xf595240b351bc8f951c2f53b26f4e78c32cb62122cf76c19b7fdda7d4968e183;

    struct Storage {
        uint256 nonce;
        mapping (uint => WitnetV2.Query) queries;
        mapping (address => bool) reporters;
    }

    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    /// Returns storage pointer to contents of 'WitnetBoardState' struct.
    function data() internal pure returns (Storage storage _ptr)
    {
        assembly {
            _ptr.slot := _WITNET_ORACLE_DATA_SLOTHASH
        }
    }

    function isReporter(address addr) internal view returns (bool) {
        return data().reporters[addr];
    }

    /// Gets query storage by query id.
    function seekQuery(uint256 _queryId) internal view returns (WitnetV2.Query storage) {
      return data().queries[_queryId];
    }

    /// Gets the Witnet.Request part of a given query.
    function seekQueryRequest(uint256 _queryId) internal view returns (WitnetV2.Request storage) {
        return data().queries[_queryId].request;
    }   

    /// Gets the Witnet.Result part of a given query.
    function seekQueryResponse(uint256 _queryId) internal view returns (WitnetV2.Response storage) {
        return data().queries[_queryId].response;
    }

    function seekQueryStatus(uint256 queryId) internal view returns (WitnetV2.QueryStatus) {
        WitnetV2.Query storage __query = data().queries[queryId];
        if (__query.response.resultTimestamp != 0) {
            if (block.number >= __query.response.finality) {
                return WitnetV2.QueryStatus.Finalized;
            } else {
                return WitnetV2.QueryStatus.Reported;
            }
        } else if (__query.request.requester != address(0)) {
            return WitnetV2.QueryStatus.Posted;
        } else {
            return WitnetV2.QueryStatus.Unknown;
        }
    }

    function seekQueryResponseStatus(uint256 queryId) internal view returns (WitnetV2.ResponseStatus) {
        WitnetV2.QueryStatus _status = seekQueryStatus(queryId);
        if (
            _status == WitnetV2.QueryStatus.Finalized
                || _status == WitnetV2.QueryStatus.Reported
        ) {
            bytes storage __cborValues = data().queries[queryId].response.resultCborBytes;
            // determine whether reported result is an error by peeking the first byte
            return (__cborValues[0] == bytes1(0xd8)
                ? (_status == WitnetV2.QueryStatus.Finalized 
                    ? WitnetV2.ResponseStatus.Error 
                    : WitnetV2.ResponseStatus.AwaitingError
                ) : (_status == WitnetV2.QueryStatus.Finalized
                    ? WitnetV2.ResponseStatus.Ready
                    : WitnetV2.ResponseStatus.AwaitingReady
                )
            );
        } else if (
            _status == WitnetV2.QueryStatus.Posted
        ) {
            return WitnetV2.ResponseStatus.Awaiting;
        } else {
            return WitnetV2.ResponseStatus.Void;
        }
    }

    // ================================================================================================================
    // --- Public functions -------------------------------------------------------------------------------------------

    function extractWitnetDataRequests(WitnetRequestBytecodes registry, uint256[] calldata queryIds)
        public view
        returns (bytes[] memory bytecodes)
    {
        bytecodes = new bytes[](queryIds.length);
        for (uint _ix = 0; _ix < queryIds.length; _ix ++) {
            if (seekQueryStatus(queryIds[_ix]) != WitnetV2.QueryStatus.Unknown) {
                WitnetV2.Request storage __request = data().queries[queryIds[_ix]].request;
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

    function notInStatusRevertMessage(WitnetV2.QueryStatus self) public pure returns (string memory) {
        if (self == WitnetV2.QueryStatus.Posted) {
            return "WitnetOracle: query not in Posted status";
        } else if (self == WitnetV2.QueryStatus.Reported) {
            return "WitnetOracle: query not in Reported status";
        } else if (self == WitnetV2.QueryStatus.Finalized) {
            return "WitnetOracle: query not in Finalized status";
        } else {
            return "WitnetOracle: bad mood";
        }
    }
}
