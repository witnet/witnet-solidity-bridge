// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetConsumer.sol";
import "../WitnetRequest.sol";

abstract contract UsingWitnetRandomness
    is
        WitnetConsumer
{
    using Witnet for bytes;
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetV2 for bytes32;
    using WitnetV2 for WitnetV2.RadonSLA;

    bytes32 internal immutable __witnetRandomnessRadHash;
    bytes32 private __defaultRandomizePackedSLA;

    constructor(WitnetRequestBoard _wrb, uint256 _maxRandomizeCallbackGas)
        UsingWitnet(_wrb)
        WitnetConsumer(_maxRandomizeCallbackGas)
    {
        // Build Witnet randomness request
        {
            WitnetRequestFactory _factory = witnet().factory();
            WitnetBytecodes _registry = witnet().registry();
            // Build own Witnet Randomness Request:
            bytes32[] memory _retrievals = new bytes32[](1);
            _retrievals[0] = _registry.verifyRadonRetrieval(
                Witnet.RadonDataRequestMethods.Rng,
                "", // no url
                "", // no body
                new string[2][](0), // no headers
                hex"80" // no retrieval script
            );
            Witnet.RadonFilter[] memory _filters;
            bytes32 _aggregator = _registry.verifyRadonReducer(Witnet.RadonReducer({
                opcode: Witnet.RadonReducerOpcodes.Mode,
                filters: _filters // no filters
            }));
            bytes32 _tally = _registry.verifyRadonReducer(Witnet.RadonReducer({
                opcode: Witnet.RadonReducerOpcodes.ConcatenateAndHash,
                filters: _filters // no filters
            }));
            WitnetRequestTemplate _template = WitnetRequestTemplate(_factory.buildRequestTemplate(
                _retrievals,
                _aggregator,
                _tally,
                0
            ));
            __witnetRandomnessRadHash = WitnetRequest(
                _template.buildRequest(new string[][](_retrievals.length))
            ).radHash();
        }
        // Settle default randomize SLA:
        __defaultRandomizePackedSLA = WitnetV2.RadonSLA({
            numWitnesses: 7,
            witnessingCollateralRatio: 10
        }).packed();
    }

    function _defaultRandomizeSLA() internal view returns (WitnetV2.RadonSLA memory) {
        return __defaultRandomizePackedSLA.toRadonSLA();
    }

    function _estimateRandomizeBaseFee() internal view returns (uint256) {
        return _witnetEstimateBaseFee(32);
    }

    /// @dev Returns index of the Most Significant Bit of the given number, applying De Bruijn O(1) algorithm.
    function _msbDeBruijn32(uint32 _v) private pure returns (uint8) {
        uint8[32] memory _bitPosition = [
            0, 9, 1, 10, 13, 21, 2, 29,
            11, 14, 16, 18, 22, 25, 3, 30,
            8, 12, 20, 28, 15, 17, 24, 7,
            19, 27, 23, 6, 26, 5, 4, 31
        ];
        _v |= _v >> 1;
        _v |= _v >> 2;
        _v |= _v >> 4;
        _v |= _v >> 8;
        _v |= _v >> 16;
        return _bitPosition[
            uint32(_v * uint256(0x07c4acdd)) >> 27
        ];
    }

    function _randomUniform(uint32 _range, uint256 _nonce, bytes32 _seed) internal pure returns (uint32) {
        uint8 _flagBits = uint8(255 - _msbDeBruijn32(_range));
        uint256 _number = uint256(
            keccak256(
                abi.encode(_seed, _nonce)
            )
        ) & uint256(2 ** _flagBits - 1);
        return uint32((_number * _range) >> _flagBits);
    }

    function _readRandomnessFromResultValue(WitnetCBOR.CBOR calldata cborValue) internal pure returns (bytes32) {
        return cborValue.readBytes().toBytes32();
    }

    function __randomize(uint256 _witnetEvmReward) virtual internal returns (uint256) {
        return __witnet.postRequest{value: _witnetEvmReward}(
            __witnetRandomnessRadHash,
            _defaultRandomizeSLA()
        );
    }

    function __randomize(
            uint256 _witnetEvmReward,
            WitnetV2.RadonSLA calldata _witnetQuerySLA
        )
        virtual internal 
        returns (uint256 _randomizeId)
    {
        return __witnet.postRequest{value: _witnetEvmReward}(
            __witnetRandomnessRadHash,
            _witnetQuerySLA
        );
    }

    function __settleRandomizeDefaultSLA(WitnetV2.RadonSLA calldata sla) virtual internal {
        __defaultRandomizePackedSLA = sla.packed();
    }
}