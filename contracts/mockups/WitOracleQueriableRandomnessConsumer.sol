// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleQueriableConsumer.sol";
import "../WitOracleRequest.sol";

abstract contract WitOracleQueriableRandomnessConsumer
    is
        WitOracleQueriableConsumer
{
    using Witnet for bytes;
    using Witnet for bytes32;
    using Witnet for Witnet.QuerySLA;
    using WitnetCBOR for WitnetCBOR.CBOR;

    Witnet.RadonHash internal immutable __witOracleRandomnessRadHash;

    /// @param _witOracle Address of the WitOracle contract.
    /// @param _baseFeeOverheadPercentage Percentage over base fee to pay as on every data request.
    /// @param _callbackGas Maximum gas to be spent by the IWitOracleQueriableConsumer's callback methods.
    constructor(
            address _witOracle, 
            uint16 _baseFeeOverheadPercentage,
            uint24 _callbackGas
        )
        UsingWitOracle(_witOracle)
        WitOracleQueriableConsumer(_callbackGas)
    {
        // On-chain building of the Witnet Randomness Request:
        {
            IWitOracleRadonRegistry _registry = IWitOracle(witOracle()).registry();
            // Build own Witnet Randomness Request:
            __witOracleRandomnessRadHash = _registry.verifyRadonRequest(
                Witnet.intoMemArray([
                    _registry.verifyRadonRetrieval(
                        Witnet.RadonRetrievalMethods.RNG,
                        "", // no url
                        "", // no body
                        new string[2][](0), // no headers
                        hex"80" // no retrieval script
                    )
                ]),
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
        __witOracleDefaultQueryParams.witResultMaxSize = 34;
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
    /// @dev as provided from the Wit/Oracle blockchain. 
    function _witOracleRandomizeSeedFromResultValue(WitnetCBOR.CBOR calldata cborValue) internal pure returns (bytes32) {
        return cborValue.readBytes().toBytes32();
    }

    /// @dev Trigger some randomness request to be solved by the Wit/Oracle blockchain, by paying the
    /// @dev exact amount of `_queryEvmReward` of the underlying WitOracle bridge contract, and based 
    /// @dev on the `__witOracleDefaultQueryParams` data security parameters. 
    function __witOracleRandomize(
            uint256 _queryEvmReward
        )
        virtual internal returns (Witnet.QueryId)
    {
        return __witOracleRandomize(
            _queryEvmReward, 
            __witOracleDefaultQueryParams
        );
    }

    /// @dev Trigger some randomness request to be solved by the Wit/Oracle blockchain, by paying the
    /// @dev exact amount of `_queryEvmReward` of the underlying WitOracle bridge contract, and based
    /// @dev on the given `_querySLA` data security parameters.
    function __witOracleRandomize(
            uint256 _queryEvmReward,
            Witnet.QuerySLA memory _querySLA
        )
        virtual internal returns (Witnet.QueryId)
    {
        return __witOracle.queryDataWithCallback{
            value: _queryEvmReward
        }(
            __witOracleRandomnessRadHash,
            _querySLA,
            Witnet.QueryCallback({
                consumer: address(this),
                gasLimit: __witOracleCallbackGasLimit
            })
        );
    }
}
