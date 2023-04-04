// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetRequestBoardTrustableBase.sol";

/// @title Witnet Request Board contract implementation for Polygon/zkEVM as of March 2023.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetRequestBoardTrustableZkEvm
    is 
        WitnetRequestBoardTrustableBase
{  
    uint256 internal immutable _ESTIMATED_REPORT_RESULT_GAS;

    constructor(
        bool _upgradable,
        bytes32 _versionTag,
        uint256 _reportResultGasLimit
    )
        WitnetRequestBoardTrustableBase(_upgradable, _versionTag, address(0))
    {
        _ESTIMATED_REPORT_RESULT_GAS = _reportResultGasLimit;
    }


    // ================================================================================================================
    // --- Overrides implementation of 'IWitnetRequestBoardRequestor' -------------------------------------------------


    /// Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// result to this request.
    /// @dev Fails if:
    /// @dev - provided reward is too low.
    /// @dev - provided script is zero address.
    /// @dev - provided script bytecode is empty.
    /// @param _addr The address of a IWitnetRequest contract, containing the actual Data Request seralized bytecode.
    /// @return _queryId An unique query identifier.
    function postRequest(IWitnetRequest _addr)
        public payable
        virtual override
        returns (uint256 _queryId)
    {
        uint256 _value = _getMsgValue();
        uint256 _gasPrice = _getGasPrice();

        // Checks the tally reward is covering gas cost
        uint256 minResultReward = estimateReward(_gasPrice);
        require(_value >= minResultReward, "WitnetRequestBoardTrustableBase: reward too low");

        // Validates provided script:
        require(address(_addr) != address(0), "WitnetRequestBoardTrustableBase: null script");

        _queryId = ++ _state().numQueries;
        _state().queries[_queryId].from = msg.sender;

        Witnet.Request storage _request = _getRequestData(_queryId);
        _request.addr = _addr;
        _request.gasprice = _gasPrice;
        _request.reward = _value;

        // Let observers know that a new request has been posted
        emit PostedRequest(_queryId, msg.sender);
    }


    // ================================================================================================================
    // --- Overrides implementation of 'IWitnetRequestBoardView' ------------------------------------------------------

    /// Estimates the amount of reward we need to insert for a given gas price.
    /// @param _gasPrice The gas price for which we need to calculate the rewards.
    function estimateReward(uint256 _gasPrice)
        public view
        virtual override
        returns (uint256)
    {
        return _gasPrice * _ESTIMATED_REPORT_RESULT_GAS;
    }


    /// Retrieves the serialized bytecode of a previously posted Witnet Data Request.
    /// @dev Fails if the `_queryId` is not valid, or if the related script bytecode 
    /// @dev got changed after being posted. Returns empty array once it gets reported, 
    /// @dev or deleted.
    /// @param _queryId The unique query identifier.
    function readRequestBytecode(uint256 _queryId)
        external view
        virtual override
        returns (bytes memory _bytecode)
    {
        require(
            _getQueryStatus(_queryId) != Witnet.QueryStatus.Unknown,
            "WitnetRequestBoardTrustableZkEvm: not yet posted"
        );
        Witnet.Request storage _request = _getRequestData(_queryId);
        if (address(_request.addr) != address(0)) {
            // if DR's request contract address is not zero,
            // we assume the DR has not been deleted, so
            // DR's bytecode can still be fetched:
            _bytecode = _request.addr.bytecode();
        } 
    }


    // ================================================================================================================
    // --- Overrides 'Payable' ----------------------------------------------------------------------------------------

    /// Gets current transaction price.
    function _getGasPrice()
        internal view
        virtual override
        returns (uint256)
    {
        return tx.gasprice;
    }

    /// Gets current payment value.
    function _getMsgValue()
        internal view
        virtual override
        returns (uint256)
    {
        return msg.value;
    }

    /// Transfers ETHs to given address.
    /// @param _to Recipient address.
    /// @param _amount Amount of ETHs to transfer.
    function _safeTransferTo(address payable _to, uint256 _amount)
        internal
        virtual override
    {
        payable(_to).transfer(_amount);
    }   
}
