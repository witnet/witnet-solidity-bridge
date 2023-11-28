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

    constructor(WitnetRequestBoard _wrb, uint96 _randomizeCallbackGasLimit)
        UsingWitnet(_wrb)
        WitnetConsumer(_randomizeCallbackGasLimit)
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
                35 // CBOR overhead (3 bytes) + payload (32 bytes)
            ));
            __witnetRandomnessRadHash = WitnetRequest(
                _template.buildRequest(new string[][](_retrievals.length))
            ).radHash();
        }
        // Settle default randomize SLA:
        __defaultRandomizePackedSLA = WitnetV2.RadonSLA({
            witnessingCommitteeSize: 7,
            witnessingCollateralRatio: 10,
            witnessingWitReward: 10 ** 9
        }).toBytes32();
    }

    function _defaultRandomizeSLA() internal view returns (WitnetV2.RadonSLA memory) {
        return __defaultRandomizePackedSLA.toRadonSLA();
    }

    function _estimateRandomizeBaseFee() internal view returns (uint256) {
        return _witnetEstimateBaseFee(35);
    }

    function _randomUniform(uint32 _range, uint256 _nonce, bytes32 _seed) internal pure returns (uint32) {
        uint256 _number = uint256(
            keccak256(
                abi.encode(_seed, _nonce)
            )
        ) & uint256(2 ** 224 - 1);
        return uint32((_number * _range) >> 224);
    }

    function _readRandomnessFromResultValue(WitnetCBOR.CBOR calldata cborValue) internal pure returns (bytes32) {
        return cborValue.readBytes().toBytes32();
    }

    function __randomize(uint256 _witnetEvmReward) virtual internal returns (uint256) {
        return __witnetRequestData(
            _witnetEvmReward,
            _defaultRandomizeSLA(),
            __witnetRandomnessRadHash
        );
    }

    function __randomize(
            uint256 _witnetEvmReward,
            WitnetV2.RadonSLA calldata _witnetQuerySLA
        )
        virtual internal 
        returns (uint256 _randomizeId)
    {
        return __witnetRequestData(
            _witnetEvmReward,
            _witnetQuerySLA,
            __witnetRandomnessRadHash
        );
    }

    function __settleRandomizeDefaultSLA(WitnetV2.RadonSLA calldata sla) virtual internal {
        __defaultRandomizePackedSLA = sla.toBytes32();
    }
}