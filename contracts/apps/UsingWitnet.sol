// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetRequestBoard.sol";

/// @title The UsingWitnet contract
/// @dev Witnet-aware contracts can inherit from this contract in order to interact with Witnet.
/// @author The Witnet Foundation.
abstract contract UsingWitnet
    is
        IWitnetRequestBoardEvents
{
    WitnetRequestBoard internal immutable __witnet;
    bytes32 private __witnetDefaultPackedSLA;

    /// @dev Include an address to specify the WitnetRequestBoard entry point address.
    /// @param _wrb The WitnetRequestBoard entry point address.
    constructor(WitnetRequestBoard _wrb) {
        require(
            _wrb.specs() == type(IWitnetRequestBoard).interfaceId,
            "UsingWitnet: uncompliant WitnetRequestBoard"
        );
        __witnet = _wrb;
        __witnetDefaultPackedSLA = WitnetV2.toBytes32(WitnetV2.RadonSLA({
            witnessingCommitteeSize: 10,
            witnessingWitTotalReward: 10 ** 9
        }));
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
        return __witnet.getQueryStatus(_id) == WitnetV2.QueryStatus.Reported;
    }

    /// @notice Estimate the minimum reward required for posting a data request, using `tx.gasprice` as a reference.
    /// @dev Underestimates if the size of returned data is greater than `_resultMaxSize`. 
    /// @param _resultMaxSize Maximum expected size of returned data (in bytes).
    function _witnetEstimateBaseFee(uint16 _resultMaxSize)
        virtual internal view
        returns (uint256)
    {
        return __witnet.estimateBaseFee(tx.gasprice, _resultMaxSize);
    }

    function _witnetCheckQueryResultAuditTrail(uint256 _witnetQueryId)
        internal view
        returns (
            uint256 _witnetResultTimestamp,
            bytes32 _witnetResultTallyHash,
            uint256 _witnetEvmFinalityBlock
        )
    {
        return __witnet.getQueryResultAuditTrail(_witnetQueryId);
    }

    function _witnetCheckQueryResultStatus(uint256 _witnetQueryId)
        internal view
        returns (WitnetV2.ResultStatus)
    {
        return __witnet.getQueryResultStatus(_witnetQueryId);
    }

    function _witnetCheckQueryResultError(uint256 _witnetQueryId)
        internal view
        returns (Witnet.ResultError memory)
    {
        return __witnet.getQueryResultError(_witnetQueryId);
    }

    function _witnetDefaultSLA() virtual internal view returns (WitnetV2.RadonSLA memory) {
        return WitnetV2.toRadonSLA(__witnetDefaultPackedSLA);
    }

    function __witnetRequestData(
            uint256 _witnetEvmReward, 
            WitnetV2.RadonSLA memory _witnetQuerySLA,
            bytes32 _witnetRadHash
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
            bytes32 _witnetRadHash
        )
        virtual internal returns (uint256)
    {
        return __witnet.postRequest{value: _witnetEvmReward}(
            _witnetRadHash,
            _witnetDefaultSLA()
        );
    }
    function __witnetSetDefaultSLA(WitnetV2.RadonSLA memory _defaultSLA) virtual internal {
        __witnetDefaultPackedSLA = WitnetV2.toBytes32(_defaultSLA);
    }
}
