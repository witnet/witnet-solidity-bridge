// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitOracleConsumer.sol";
import "../WitOracleRequest.sol";

abstract contract WitOracleRandomnessConsumer
    is
        WitOracleConsumer
{
    using Witnet for bytes;
    using Witnet for bytes32;
    using Witnet for Witnet.RadonSLA;
    using WitnetCBOR for WitnetCBOR.CBOR;

    bytes32 internal immutable __witOracleRandomnessRadHash;

    /// @param _witOracle Address of the WitOracle contract.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGasLimit Maximum gas to be spent by the IWitOracleConsumer's callback methods.
    constructor(
            WitOracle _witOracle, 
            uint16 _baseFeeOverheadPercentage,
            uint24 _callbackGasLimit
        )
        UsingWitOracle(_witOracle)
        WitOracleConsumer(_callbackGasLimit)
    {
        // On-chain building of the Witnet Randomness Request:
        {
            WitOracleRadonRegistry _registry = witOracle().registry();
            // Build own Witnet Randomness Request:
            __witOracleRandomnessRadHash = _registry.verifyRadonRequest(
                abi.decode(
                    abi.encode([
                        _registry.verifyRadonRetrieval(
                            Witnet.RadonRetrievalMethods.RNG,
                            "", // no url
                            "", // no body
                            new string[2][](0), // no headers
                            hex"80" // no retrieval script
                        )
                    ]), (bytes32[])
                ),
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
        __witOracleBaseFeeOverheadPercentage = _baseFeeOverheadPercentage;
        __witOracleDefaultQuerySLA.maxTallyResultSize = 34;
        
    }

    /// @dev Pure P-RNG generator returning uniformly distributed `_range` values based on
    /// @dev given `_nonce` and `_seed` values. 
    function _witOracleRandomUniformUint32(
            uint32 _range, 
            uint256 _nonce, 
            bytes32 _seed
        )
        internal pure returns (uint32)
    {
        uint256 _number = uint256(
            keccak256(
                abi.encode(_seed, _nonce)
            )
        ) & uint256(2 ** 224 - 1);
        return uint32((_number * _range) >> 224);
    }

    /// @dev Helper function for decoding randomness seed embedded within a CBOR-encoded result
    /// @dev as provided from the Wit/oracle blockchain. 
    function _witOracleRandomizeSeedFromResultValue(WitnetCBOR.CBOR calldata cborValue) internal pure returns (bytes32) {
        return cborValue.readBytes().toBytes32();
    }

    /// @dev Trigger some randomness request to be solved by the Wit/oracle blockchain, by paying the
    /// @dev exact amount of `_queryEvmReward` of the underlying WitOracle bridge contract, and based 
    /// @dev on the `__witOracleDefaultQuerySLA` data security parameters. 
    function __witOracleRandomize(
            uint256 _queryEvmReward
        )
        virtual internal returns (uint256)
    {
        return __witOracleRandomize(
            _queryEvmReward, 
            __witOracleDefaultQuerySLA
        );
    }

    /// @dev Trigger some randomness request to be solved by the Wit/oracle blockchain, by paying the
    /// @dev exact amount of `_queryEvmReward` of the underlying WitOracle bridge contract, and based
    /// @dev on the given `_querySLA` data security parameters.
    function __witOracleRandomize(
            uint256 _queryEvmReward,
            Witnet.RadonSLA memory _querySLA
        )
        virtual internal returns (uint256)
    {
        return __witOracle.postQueryWithCallback{
            value: _queryEvmReward
        }(
            __witOracleRandomnessRadHash,
            _querySLA,
            __witOracleCallbackGasLimit
        );
    }
}
