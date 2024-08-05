// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitOracleConsumer.sol";
import "../WitOracleRequest.sol";

abstract contract WitRandomnessRequestConsumer
    is
        WitOracleConsumer
{
    using Witnet for bytes;
    using Witnet for bytes32;
    using Witnet for Witnet.RadonSLA;
    using WitnetCBOR for WitnetCBOR.CBOR;

    bytes32 internal immutable __witnetRandomnessRadHash;

    /// @param _wrb Address of the WitOracle contract.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGasLimit Maximum gas to be spent by the IWitOracleConsumer's callback methods.
    constructor(
            WitOracle _wrb, 
            uint16 _baseFeeOverheadPercentage,
            uint24 _callbackGasLimit
        )
        UsingWitOracle(_wrb)
        WitOracleConsumer(_callbackGasLimit)
    {
        // On-chain building of the Witnet Randomness Request:
        {
            WitOracleRadonRegistry _registry = witnet().registry();
            // Build own Witnet Randomness Request:
            bytes32[] memory _retrievals = new bytes32[](1);
            _retrievals[0] = _registry.verifyRadonRetrieval(
                Witnet.RadonRetrievalMethods.RNG,
                "", // no url
                "", // no body
                new string[2][](0), // no headers
                hex"80" // no retrieval script
            );
            __witnetRandomnessRadHash = _registry.verifyRadonRequest(
                _retrievals,
                Witnet.RadonReducer({
                    opcode: Witnet.RadonReduceOpcodes.Mode,
                    filters: new Witnet.RadonFilter[](0)
                }),
                Witnet.RadonReducer({
                    opcode: Witnet.RadonReduceOpcodes.ConcatenateAndHash,
                    filters: new Witnet.RadonFilter[](0)
                })
            );
        }
        __witnetBaseFeeOverheadPercentage = _baseFeeOverheadPercentage;
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
        return __witnetRandomize(_witnetEvmReward, __witnetDefaultSLA);
    }

    function __witnetRandomize(
            uint256 _witnetEvmReward,
            Witnet.RadonSLA memory _witOracleQuerySLA
        )
        virtual internal 
        returns (uint256 _randomizeId)
    {
        return __witnet.postRequestWithCallback{
            value: _witnetEvmReward
        }(
            __witnetRandomnessRadHash,
            _witOracleQuerySLA,
            __witnetCallbackGasLimit
        );
    }
}
