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
        uint8  numWitnesses;
        uint8  witnessingCollateralRatio;
    }

    function equalOrGreaterThan(RadonSLA memory a, RadonSLA memory b) 
        internal pure returns (bool)
    {
        return (
            a.numWitnesses * a.witnessingCollateralRatio 
                >= b.numWitnesses * b.witnessingCollateralRatio
        );
    }
     
    function isValid(RadonSLA calldata sla) internal pure returns (bool) {
        return (
            sla.numWitnesses > 0 && sla.numWitnesses <= 127
                && sla.witnessingCollateralRatio > 0 && sla.witnessingCollateralRatio <= 127
        );
    }

    function packed(RadonSLA memory sla) internal pure returns (bytes32) {
        return bytes32(
            uint(sla.numWitnesses) << 248
                | uint(sla.witnessingCollateralRatio) << 240
        );
    }

    function toRadonSLA(bytes32 _packed)
        internal pure returns (RadonSLA memory)
    {
        return RadonSLA({
            numWitnesses: uint8(uint(_packed >> 248)),
            witnessingCollateralRatio: uint8(uint(_packed >> 240))
        });
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