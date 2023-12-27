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

    /// @param _wrb Address of the WitnetRequestBoard contract.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGasLimit Maximum gas to be spent by the IWitnetConsumer's callback methods.
    /// @param _defaultSLA Default Security-Level Agreement parameters to be fulfilled by the Witnet blockchain.
    constructor(
            WitnetRequestBoard _wrb, 
            uint16 _baseFeeOverheadPercentage,
            uint96 _callbackGasLimit,
            WitnetV2.RadonSLA memory _defaultSLA
        )
        UsingWitnet(_wrb)
        WitnetConsumer(_callbackGasLimit)
    {
        // On-chain building of the Witnet Randomness Request:
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
                32 // 256 bits of pure entropy ;-)
            ));
            __witnetRandomnessRadHash = WitnetRequest(
                _template.buildRequest(new string[][](_retrievals.length))
            ).radHash();
        }
        // Settle default randomize SLA:
        __witnetSetDefaultSLA(_defaultSLA);
        __witnetSetBaseFeeOverheadPercentage(_baseFeeOverheadPercentage);
    }

    function _witnetEstimateEvmReward() virtual override internal view returns (uint256) {
        return _witnetEstimateEvmReward(32);
    }

    function _witnetRandomUniformUint32(uint32 _range, uint256 _nonce, bytes32 _seed) internal pure returns (uint32) {
        uint256 _number = uint256(
            keccak256(
                abi.encode(_seed, _nonce)
            )
        ) & uint256(2 ** 224 - 1);
        return uint32((_number * _range) >> 224);
    }

    function _witnetReadRandomizeFromResultValue(WitnetCBOR.CBOR calldata cborValue) internal pure returns (bytes32) {
        return cborValue.readBytes().toBytes32();
    }

    function __witnetRandomize(uint256 _witnetEvmReward) virtual internal returns (uint256) {
        return __witnetRandomize(_witnetEvmReward, _witnetDefaultSLA());
    }

    function __witnetRandomize(
            uint256 _witnetEvmReward,
            WitnetV2.RadonSLA memory _witnetQuerySLA
        )
        virtual internal 
        returns (uint256 _randomizeId)
    {
        return __witnet.postRequest{value: _witnetEvmReward}(
            __witnetRandomnessRadHash,
            _witnetQuerySLA
        );
    }
}
