// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./Witnet.sol";

library WitnetV2 {

    /// Struct containing both request and response data related to every query posted to the Witnet Request Board
    struct Query {
        Request request;
        Response response;
    }

    /// Possible status of a Witnet query.
    enum QueryStatus {
        Unknown,
        Posted,
        Reported,
        Finalized
    }

    /// Data kept in EVM-storage for every Request posted to the Witnet Request Board.
    struct Request {
        address requester;              // EVM address from which the request was posted.
        uint24  gasCallback;            // Max callback gas limit upon response, if a callback is required.
        uint72  evmReward;              // EVM amount in wei eventually to be paid to the legit result reporter.
        bytes   witnetBytecode;         // Optional: Witnet Data Request bytecode to be solved by the Witnet blockchain.
        bytes32 witnetRAD;              // Optional: Previously verified hash of the Witnet Data Request to be solved.
        WitnetV2.RadonSLA witnetSLA;    // Minimum Service-Level parameters to be committed by the Witnet blockchain. 
    }

    /// Response metadata and result as resolved by the Witnet blockchain.
    struct Response {
        address reporter;               // EVM address from which the Data Request result was reported.
        uint64  finality;               // EVM block number at which the reported data will be considered to be finalized.
        uint32  resultTimestamp;        // Unix timestamp (seconds) at which the data request was resolved in the Witnet blockchain.
        bytes32 resultTallyHash;        // Unique hash of the commit/reveal act in the Witnet blockchain that resolved the data request.
        bytes   resultCborBytes;        // CBOR-encode result to the request, as resolved in the Witnet blockchain.
    }

    /// Response status from a requester's point of view.
    enum ResponseStatus {
        Void,
        Awaiting,
        Ready,
        Error,
        AwaitingReady,
        AwaitingError
    }

    struct RadonSLA {
        /// @notice Number of nodes in the Witnet blockchain that will take part in solving the data request. 
        uint8   committeeSize;
        
        /// @notice Fee in $nanoWIT paid to every node in the Witnet blockchain involved in solving the data request.
        /// @dev Witnet nodes participating as witnesses will have to stake as collateral 100x this amount.
        uint64  witnessingFeeNanoWit;
    }

    
    /// ===============================================================================================================
    /// --- 'WitnetV2.RadonSLA' helper methods ------------------------------------------------------------------------

    function equalOrGreaterThan(RadonSLA memory a, RadonSLA memory b) 
        internal pure returns (bool)
    {
        return (a.committeeSize >= b.committeeSize);
    }
     
    function isValid(RadonSLA calldata sla) internal pure returns (bool) {
        return (
            sla.witnessingFeeNanoWit > 0 
                && sla.committeeSize > 0 && sla.committeeSize <= 127
                // v1.7.x requires witnessing collateral to be greater or equal to 20 WIT:
                && sla.witnessingFeeNanoWit * 100 >= 20 * 10 ** 9 
        );
    }

    function toV1(RadonSLA memory self) internal pure returns (Witnet.RadonSLA memory) {
        return Witnet.RadonSLA({
            numWitnesses: self.committeeSize,
            minConsensusPercentage: 51,
            witnessReward: self.witnessingFeeNanoWit,
            witnessCollateral: self.witnessingFeeNanoWit * 100,
            minerCommitRevealFee: self.witnessingFeeNanoWit / self.committeeSize
        });
    }

    function nanoWitTotalFee(RadonSLA storage self) internal view returns (uint64) {
        return self.witnessingFeeNanoWit * (self.committeeSize + 3);
    }

    uint256 internal constant _WITNET_GENESIS_TIMESTAMP = 1602666045;
    uint256 internal constant _WITNET_GENESIS_EPOCH_SECONDS = 45;

    uint256 internal constant _WITNET_2_0_EPOCH = 1234567;
    uint256 internal constant _WITNET_2_0_EPOCH_SECONDS = 30;
    uint256 internal constant _WITNET_2_0_TIMESTAMP = _WITNET_GENESIS_TIMESTAMP + _WITNET_2_0_EPOCH * _WITNET_GENESIS_EPOCH_SECONDS;

    function timestampToWitnetEpoch(uint _timestamp) internal pure returns (uint) {
        if (_timestamp > _WITNET_2_0_TIMESTAMP ) {
            return (
                _WITNET_2_0_EPOCH + (
                    _timestamp - _WITNET_2_0_TIMESTAMP
                ) / _WITNET_2_0_EPOCH_SECONDS
            );
        } else if (_timestamp > _WITNET_GENESIS_TIMESTAMP) {
            return (
                1 + (
                    _timestamp - _WITNET_GENESIS_TIMESTAMP
                ) / _WITNET_GENESIS_EPOCH_SECONDS
            );
        } else {
            return 0;
        }
    }

    function witnetEpochToTimestamp(uint _epoch) internal pure returns (uint) {
        if (_epoch >= _WITNET_2_0_EPOCH) {
            return (
                _WITNET_2_0_TIMESTAMP + (
                    _epoch - _WITNET_2_0_EPOCH
                ) * _WITNET_2_0_EPOCH_SECONDS
            );
        } else {
            return (_WITNET_GENESIS_TIMESTAMP + _epoch * _WITNET_GENESIS_EPOCH_SECONDS);
        }
    }
}