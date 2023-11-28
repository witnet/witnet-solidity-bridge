// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./Witnet.sol";

library WitnetV2 {

    uint256 internal constant _WITNET_GENESIS_TIMESTAMP = 1602666045;
    uint256 internal constant _WITNET_GENESIS_EPOCH_SECONDS = 45;

    uint256 internal constant _WITNET_2_0_EPOCH = 1234567;
    uint256 internal constant _WITNET_2_0_EPOCH_SECONDS = 30;
    uint256 internal constant _WITNET_2_0_TIMESTAMP = _WITNET_GENESIS_TIMESTAMP + _WITNET_2_0_EPOCH * _WITNET_GENESIS_EPOCH_SECONDS;

    struct RadonSLA {
        /// @dev Number of witnessing nodes that will take part in the resolution of a data request within the Witnet blockchain:
        uint8   witnessingCommitteeSize;   
        /// @dev Collateral-to-reward ratio that witnessing nodes will have to commit with when taking part in a data request resolution.
        uint8   witnessingCollateralRatio;
        /// @dev Minimum amount of $nanoWIT that all Witnet nodes participating in the resolution of a data request will receive as a reward:
        uint64  witnessingWitReward;
    }

    function equalOrGreaterThan(RadonSLA memory a, RadonSLA memory b) 
        internal pure returns (bool)
    {
        return (
            a.witnessingCommitteeSize * a.witnessingCollateralRatio * a.witnessingWitReward
                >= b.witnessingCommitteeSize * b.witnessingCollateralRatio * b.witnessingWitReward
        );
    }
     
    function isValid(RadonSLA calldata sla) internal pure returns (bool) {
        return (
            sla.witnessingWitReward > 0 
                && sla.witnessingCommitteeSize > 0 && sla.witnessingCommitteeSize <= 127
                && sla.witnessingCollateralRatio > 0 && sla.witnessingCollateralRatio <= 127
        );
    }

    function toBytes32(RadonSLA memory sla) internal pure returns (bytes32) {
        return bytes32(
            uint(sla.witnessingCommitteeSize) << 248
                | uint(sla.witnessingCollateralRatio) << 240
                // | uint(sla.witnessingNotBeforeTimestamp) << 64
                | uint(sla.witnessingWitReward)
        );
    }

    function toRadonSLA(bytes32 _packed)
        internal pure returns (RadonSLA memory)
    {
        return RadonSLA({
            witnessingCommitteeSize: uint8(uint(_packed) >> 248),
            witnessingCollateralRatio: uint8(uint(_packed) >> 240),
            // witnessingNotBeforeTimestamp: uint64(uint(_packed) >> 64),
            witnessingWitReward: uint64(uint(_packed))
        });
    }

    function totalWitnessingReward(WitnetV2.RadonSLA calldata sla) internal pure returns (uint64) {
        return (
            (3 + sla.witnessingCommitteeSize)
                * sla.witnessingWitReward
        );
    }

    function totalWitnessingReward(bytes32 _packed) internal pure returns (uint64) {
        return (
            (3 + (uint8(uint(_packed) << 248))) // 3 + witnessingCommitteSize
                * uint64(uint(_packed))         // witnessingWitReward
        );      
    }

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