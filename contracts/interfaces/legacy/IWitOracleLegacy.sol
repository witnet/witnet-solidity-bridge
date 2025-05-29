// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../IWitOracleRadonRegistry.sol";

interface IWitOracleLegacy {

    struct RadonSLA {
        uint8  witCommitteeSize;
        uint64 witUnitaryReward;
    }

    event WitnetQuery(uint256 id, uint256 evmReward, RadonSLA witnetSLA);

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `resultMaxSize`. 
    /// @param gasPrice Expected gas price to pay upon posting the data request.
    /// @param resultMaxSize Maximum expected size of returned data (in bytes).  
    function estimateBaseFee(uint256 gasPrice, uint16 resultMaxSize) external view returns (uint256);
    
    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Fails if the RAD hash was not previously verified on the WitOracleRadonRegistry registry.
    /// @param gasPrice Expected gas price to pay upon posting the data request.
    /// @param radHash The RAD hash of the data request to be solved by Witnet.
    function estimateBaseFee(uint256 gasPrice, bytes32 radHash) external view returns (uint256);

    /// @notice Returns query's result current status from a requester's point of view:
    /// @notice   - 0 => Void: the query is either non-existent or deleted;
    /// @notice   - 1 => Awaiting: the query has not yet been reported;
    /// @notice   - 2 => Ready: the query response was finalized, and contains a result with no erros.
    /// @notice   - 3 => Error: the query response was finalized, and contains a result with errors.
    /// @notice   - 4 => Finalizing: some result to the query has been reported, but cannot yet be considered finalized.
    /// @notice   - 5 => Delivered: at least one response, either successful or with errors, was delivered to the requesting contract.
    function getQueryResponseStatus(uint256) external view returns (QueryResponseStatus);

        /// QueryResponse status from a requester's point of view.
        enum QueryResponseStatus {
            Void,
            Awaiting,
            Ready,
            Error,
            Finalizing,
            Delivered,
            Expired
        }

    /// @notice Retrieves the CBOR-encoded buffer containing the Witnet-provided result to the given query.
    function getQueryResultCborBytes(uint256) external view returns (bytes memory);

    /// @notice Gets error code identifying some possible failure on the resolution of the given query.
    function getQueryResultError(uint256) external view returns (ResultError memory);

        /// Data struct describing an error when trying to fetch a Witnet-provided result to a Data Request.
        struct ResultError {
            uint8 code;
            string reason;
        }

    function extractWitnetDataRequests(uint256[] calldata queryIds) external view returns (bytes[] memory);
    function fetchQueryResponse(uint256 queryId) external returns (bytes memory);
    function postRequest(bytes32, RadonSLA calldata) external payable returns (uint256);
    function postRequestWithCallback(bytes32, RadonSLA calldata, uint24) external payable returns (uint256);
    function reportResult(uint256, uint32, bytes32, bytes calldata) external returns (uint256);
    function reportResult(uint256, bytes32, bytes calldata) external returns (uint256);

    struct BatchResultLegacy {
        uint256 queryId;
        uint32 drTxTimestamp;
        bytes32 drTxHash;
        bytes resultCborBytes;
    }
    function reportResultBatch(BatchResultLegacy[] calldata) external returns (uint256);
}
