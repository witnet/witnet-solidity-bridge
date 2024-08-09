// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../../contracts/mockups/WitOracleRandomnessConsumer.sol";

contract MyDapp
    is
        WitOracleRandomnessConsumer
{
    using WitnetCBOR for WitnetCBOR.CBOR;

    event Randomizing(uint256 queryId);
    event Randomized(uint256 queryId, bytes32 randomness);
    event Error(uint256 queryId, Witnet.ResultErrorCodes errorCode);

    bytes32 public randomness;
    bytes32 public witnetRandomnessRadHash;
    uint64  public immutable callbackGasLimit;
    bytes public witnetRandomnessBytecode;
    struct Rubbish {
        bytes32 slot1;
        bytes32 slot2;
        bytes32 slot3;
    }
    Rubbish public rubbish;

    uint256 private immutable __randomizeValue;

    constructor(WitOracle _witOracle, uint16 _baseFeeOverheadPercentage, uint24 _callbackGasLimit)
        WitOracleRandomnessConsumer(
            _witOracle, 
            _baseFeeOverheadPercentage,
            _callbackGasLimit
        )
    {
        callbackGasLimit = _callbackGasLimit;
        rubbish.slot1 = blockhash(block.number - 1);
        rubbish.slot2 = blockhash(block.number - 2);
        rubbish.slot3 = blockhash(block.number - 3);
        witnetRandomnessRadHash = __witOracleRandomnessRadHash;
        witnetRandomnessBytecode = witOracle().registry().bytecodeOf(__witOracleRandomnessRadHash);
        __randomizeValue = _witOracleEstimateBaseFee();
    }

    function getRandomizeValue() external view returns (uint256) {
        return __randomizeValue;
    }

    function randomize() external payable returns (uint256 _randomizeId) {
        _randomizeId = __witOracleRandomize(__randomizeValue);
        if (__randomizeValue < msg.value) {
            payable(msg.sender).transfer(msg.value - __randomizeValue);
        }
    }

    /// @notice Method to be called from the WitOracle contract as soon as the given Witnet `queryId`
    /// @notice gets reported, if reported with no errors.
    /// @dev It should revert if called from any other address different to the WitOracle being used
    /// @dev by the WitOracleConsumer contract. Within the implementation of this method, the WitOracleConsumer
    /// @dev can call to the WRB as to retrieve the Witnet tracking information (i.e. the `witnetDrTxHash` 
    /// @dev and `witnetDrCommitTxTimestamp`), or the finality status, of the result being reported.
    function reportWitOracleResultValue(
            uint256 _queryId, uint64, bytes32, uint256,
            WitnetCBOR.CBOR calldata witnetResultCborValue
        )
        override external
        onlyFromWitnet
    {
        // randomness = _witOracleRandomizeSeedFromResultValue(witnetResultCborValue);
        // delete rubbish;
        // witOracle.burnQuery(_queryId);
        // emit Result(queryId, _witOracleRandomizeSeedFromResultValue(cborValue));
    }

    function reportWitOracleResultError(
            uint256 queryId, 
            uint64, bytes32, uint256, 
            Witnet.ResultErrorCodes errorCode, WitnetCBOR.CBOR calldata
        )
        virtual external
        onlyFromWitnet
    {
        emit Error(queryId, errorCode);
    }


}
