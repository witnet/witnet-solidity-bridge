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
        Undeliverable,
        Finalized
    }

    /// Data kept in EVM-storage for every Request posted to the Witnet Request Board.
    struct Request {
        bytes32 fromCallbackGas; // Packed: contains requester address in most significant bytes20, 
                                 //         and max callback gas limit if a callback is required.
        bytes32 SLA;             // Packed: Service-Level Aggreement parameters upon which the data request 
                                 //         will be solved by the Witnet blockchain.
        bytes32 RAD;             // Verified hash of the actual data request to be solved by the Witnet blockchain.
        uint256 reserved1;       // Reserved uint256 slot.
        uint256 evmReward;       // EVM reward to be paid to the relayer of the Witnet resolution to the data request.
        bytes   bytecode;        // Raw bytecode of the data request to be solved by the Witnet blockchain (only if not yet verified).
    }

    /// Data kept in EVM-storage containing Witnet-provided response metadata and result.
    struct Response {
        bytes32 fromFinality;  // Packed: contains address from which the result to the data request was reported, and 
                               //         the EVM block at which the provided result can be considered to be final.        
        uint256 timestamp;     // Timestamp at which data from data sources were retrieved by the Witnet blockchain. 
        bytes32 tallyHash;     // Hash of the Witnet commit/reveal act that solved the data request.
        bytes   cborBytes;     // CBOR-encoded result to the data request, as resolved by the Witnet blockchain. 
    }

        /// Final query's result status from a requester's point of view.
    enum ResultStatus {
        Void,
        Awaiting,
        Ready,
        Error,
        AwaitingReady,
        AwaitingError
    }

    struct RadonSLA {
        /// @dev Number of witnessing nodes that will take part in the resolution 
        /// @dev of a data request within the Witnet blockchain:
        uint8   witnessingCommitteeSize;   
        
        /// @dev Total reward in $nanoWIT that will be equally distributed to all nodes
        /// @dev involved in the resolution of a data request in the Witnet blockchain:
        uint64  witnessingWitTotalReward;
    }

    /// ===============================================================================================================
    /// --- 'WitnetV2.Request' helper methods -------------------------------------------------------------------------

    function packRequesterCallbackGasLimit(address requester, uint96 callbackGasLimit) internal pure returns (bytes32) {
        return bytes32(uint(bytes32(bytes20(requester))) | callbackGasLimit);
    }

    function unpackRequester(Request storage self) internal view returns (address) {
        return address(bytes20(self.fromCallbackGas));
    }

    function unpackCallbackGasLimit(Request storage self) internal view returns (uint96) {
        return uint96(uint(self.fromCallbackGas));
    }

    function unpackRequesterAndCallbackGasLimit(Request storage self) internal view returns (address, uint96) {
        bytes32 _packed = self.fromCallbackGas;
        return (address(bytes20(_packed)), uint96(uint(_packed)));
    }

    
    /// ===============================================================================================================
    /// --- 'WitnetV2.Response' helper methods ------------------------------------------------------------------------

    function packReporterEvmFinalityBlock(address reporter, uint256 evmFinalityBlock) internal pure returns (bytes32) {
        return bytes32(uint(bytes32(bytes20(reporter))) << 96 | uint96(evmFinalityBlock));
    }

    function unpackWitnetReporter(Response storage self) internal view returns (address) {
        return address(bytes20(self.fromFinality));
    }

    function unpackEvmFinalityBlock(Response storage self) internal view returns (uint256) {
        return uint(uint96(uint(self.fromFinality)));
    }

    function unpackEvmFinalityBlock(bytes32 fromFinality) internal pure returns (uint256) {
        return uint(uint96(uint(fromFinality)));
    }

    function unpackWitnetReporterAndEvmFinalityBlock(Response storage self) internal view returns (address, uint256) {
        bytes32 _packed = self.fromFinality;
        return (address(bytes20(_packed)), uint(uint96(uint(_packed))));
    }

    
    /// ===============================================================================================================
    /// --- 'WitnetV2.RadonSLA' helper methods ------------------------------------------------------------------------

    function equalOrGreaterThan(RadonSLA memory a, RadonSLA memory b) 
        internal pure returns (bool)
    {
        return (a.witnessingCommitteeSize >= b.witnessingCommitteeSize);
    }
     
    function isValid(RadonSLA calldata sla) internal pure returns (bool) {
        return (
            sla.witnessingWitTotalReward > 0 
                && sla.witnessingCommitteeSize > 0 && sla.witnessingCommitteeSize <= 127
        );
    }

    function toBytes32(RadonSLA memory sla) internal pure returns (bytes32) {
        return bytes32(
            uint(sla.witnessingCommitteeSize) << 248
                // | uint(sla.witnessingCollateralRatio) << 240
                // | uint(sla.witnessingNotBeforeTimestamp) << 64
                | uint(sla.witnessingWitTotalReward)
        );
    }

    function toRadonSLA(bytes32 _packed)
        internal pure returns (RadonSLA memory)
    {
        return RadonSLA({
            witnessingCommitteeSize: uint8(uint(_packed) >> 248),
            // witnessingCollateralRatio: uint8(uint(_packed) >> 240),
            // witnessingNotBeforeTimestamp: uint64(uint(_packed) >> 64),
            witnessingWitTotalReward: uint64(uint(_packed))
        });
    }

    function witnessingWitTotalReward(bytes32 _packed) internal pure returns (uint64) {
        return uint64(uint(_packed));
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