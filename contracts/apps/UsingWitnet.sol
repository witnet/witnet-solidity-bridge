// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetRequestBoard.sol";

/// @title The UsingWitnet contract
/// @dev Witnet-aware contracts can inherit from this contract in order to interact with Witnet.
/// @author The Witnet Foundation.
abstract contract UsingWitnet {

    WitnetRequestBoard internal immutable __witnet;

    /// @dev Include an address to specify the WitnetRequestBoard entry point address.
    /// @param _wrb The WitnetRequestBoard entry point address.
    constructor(WitnetRequestBoard _wrb) {
        require(
            _wrb.class() == type(IWitnetRequestBoard).interfaceId,
            "UsingWitnet: uncompliant WitnetRequestBoard"
        );
        __witnet = _wrb;
    }

    /// @dev Provides a convenient way for client contracts extending this to block the execution of the main logic of the
    /// @dev contract until a particular request has been successfully solved and reported by Witnet,
    /// @dev either with an error or successfully.
    modifier witnetQuerySolved(uint256 _witnetQueryId) {
        require(_witnetCheckQueryResultAvailability(_witnetQueryId), "UsingWitnet: unsolved query");
        _;
    }

    function witnet() virtual public view returns (WitnetRequestBoard) {
        return __witnet;
    }

    /// @notice Check if given query was already reported back from the Witnet oracle.
    /// @param _id The unique identifier of a previously posted data request.
    function _witnetCheckQueryResultAvailability(uint256 _id)
        internal view
        returns (bool)
    {
        return __witnet.getQueryStatus(_id) == Witnet.QueryStatus.Reported;
    }

    /// @notice Estimate the minimum reward required for posting a data request, using `tx.gasprice` as a reference.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _resultMaxSize Maximum expected size of returned data (in bytes).
    function _witnetEstimateBaseFee(uint256 _resultMaxSize)
        internal view
        returns (uint256)
    {
        return __witnet.estimateBaseFee(tx.gasprice, _resultMaxSize);
    }

    /// @notice Estimate the minimum reward required for posting a data request, using `tx.gasprice` as a reference.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _maxCallbackGas Maximum gas to be spent when reporting the data request result.
    function _witnetEstimateBaseFeeWithCallback(uint256 _maxCallbackGas)
        internal view
        returns (uint256)
    {
        return __witnet.estimateBaseFeeWithCallback(tx.gasprice, _maxCallbackGas);
    }

    function _witnetCheckQueryResultTraceability(uint256 _witnetQueryId)
        internal view
        returns (
            uint256 _witnetQueryResponseTimestamp,
            bytes32 _witnetQueryResponseDrTxHash
        )
    {
        return __witnet.checkResultTraceability(_witnetQueryId);
    }

    function _witnetCheckQueryResultStatus(uint256 _witnetQueryId)
        internal view
        returns (Witnet.ResultStatus)
    {
        return __witnet.checkResultStatus(_witnetQueryId);
    }

    function _witnetCheckQueryResultError(uint256 _witnetQueryId)
        internal view
        returns (Witnet.ResultError memory)
    {
        return __witnet.checkResultError(_witnetQueryId);
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward, 
            bytes32 _witnetRadHash,
            WitnetV2.RadonSLA calldata _witnetQuerySLA
        )
        virtual internal returns (uint256)
    {
        return __witnet.postRequest{value: _witnetEvmReward}(
            _witnetRadHash, 
            _witnetQuerySLA
        );
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward,
            bytes calldata _witnetRadBytecode,
            WitnetV2.RadonSLA calldata _witnetQuerySLA
        )
        virtual internal returns (uint256)
    {
        return __witnet.postRequest{value: _witnetEvmReward}(
            _witnetRadBytecode,
            _witnetQuerySLA
        );
    }
}
