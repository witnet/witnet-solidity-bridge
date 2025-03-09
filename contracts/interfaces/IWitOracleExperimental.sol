// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitOracleConsumer.sol";

import "../WitOracleRadonRegistry.sol";

interface IWitOracleExperimental {
    
    event WitOracleServiceCommittee(
        address indexed evmSubscriber,
        bytes32 indexed witRadHash,
        Witnet.ServiceProvider[] witServiceCommittee
    );

    /// @notice Enables data requesters to settle the actual validators in the Wit/Oracle
    /// @notice sidechain that will be entitled to solve data requests requiring to
    /// @notice support the specified Radon Request hash (i.e. RAD hash).
    function settleMyOwnServiceCommittee(bytes32 radHash, Witnet.ServiceProvider[] calldata) external;

    /// Structure containing extra query params for Delegated Data Requests and optional Service Committees
    struct QueryParams {
        uint16 witResultMaxSize;
        uint16 witCommitteeSize;
        uint64 witInclusionFees;
        Witnet.ServiceProvider[] providers;
    }

    /// Delegated Data Requests
    struct DDR {
        Witnet.QueryId queryId;
        Witnet.QueryHash queryHash;
        Witnet.QueryEvmReward queryEvmReward;
        QueryParams queryParams;
        bytes radonBytecode;
    }

    function extractDelegatedDataRequest(Witnet.QueryId queryId) external view returns (DDR memory);
    function extractDelegatedDataRequestBatch(Witnet.QueryId[] calldata queryIds) external view returns (DDR[] memory);
}
