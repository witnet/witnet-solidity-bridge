// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitOracleBasePushOnly.sol";
import "../WitnetUpgradableBase.sol";
import "../../data/WitOracleDataLib.sol";
import "../../interfaces/IWitOracleTrustableAdmin.sol";

/// @title Push-only WitOracle "trustable" base implementation.
/// @author The Witnet Foundation
abstract contract WitOracleBasePushOnlyTrustable
    is 
        WitnetUpgradableBase,
        WitOracleBasePushOnly,
        IWitOracleTrustableAdmin
{
    using Witnet for Witnet.DataPushReport;

    constructor(bytes32 _versionTag)
        Ownable(msg.sender)
        WitnetUpgradableBase(
            true, 
            _versionTag,
            "io.witnet.proxiable.board"
        )
    {}


    // ================================================================================================================
    // --- Upgradeable ------------------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    function __initializeUpgradableData(bytes memory _initData) virtual override internal {
        if (_initData.length > 0) {
            WitOracleDataLib.setReporters(abi.decode(_initData, (address[])));
        }
    }

    
    // ================================================================================================================
    // --- IWitOracle -------------------------------------------------------------------------------------------------

    function parseDataReport(Witnet.DataPushReport calldata _report, bytes calldata _signature)
        virtual override public view
        returns (Witnet.DataResult memory _result)
    {
        (, _result) = WitOracleDataLib.parseDataReport(_report, _signature);
    }

    function pushDataReport(Witnet.DataPushReport calldata _report, bytes calldata _signature)
        virtual override external
        returns (Witnet.DataResult memory)
    {
        (address _evmSigner, Witnet.DataResult memory _result) = WitOracleDataLib.parseDataReport(_report, _signature);
        emit WitOracleReport(
            tx.origin, 
            msg.sender, 
            _evmSigner, 
            _report.witDrTxHash,
            _report.queryRadHash,
            _report.queryParams,
            _report.resultTimestamp,
            _report.resultCborBytes
        );
        return _result;
    }


    // ================================================================================================================
    // --- IWitOracleTrustableAdmin ----------------------------------------------------------------------------------------

    /// Tells whether given address is included in the active reporters control list.
    /// @param _queryResponseReporter The address to be checked.
    function isReporter(address _queryResponseReporter) virtual override public view returns (bool) {
        return WitOracleDataLib.isReporter(_queryResponseReporter);
    }

    /// Adds given addresses to the active reporters control list.
    /// @dev Can only be called from the owner address.
    /// @dev Emits the `ReportersSet` event. 
    /// @param _queryResponseReporters List of addresses to be added to the active reporters control list.
    function setReporters(address[] calldata _queryResponseReporters)
        virtual override public
        onlyOwner
    {
        WitOracleDataLib.setReporters(_queryResponseReporters);
    }

    /// Removes given addresses from the active reporters control list.
    /// @dev Can only be called from the owner address.
    /// @dev Emits the `ReportersUnset` event. 
    /// @param _exReporters List of addresses to be added to the active reporters control list.
    function unsetReporters(address[] calldata _exReporters)
        virtual override public
        onlyOwner
    {
        WitOracleDataLib.unsetReporters(_exReporters);
    }


    // ================================================================================================================
    // --- Internal functions -----------------------------------------------------------------------------------------

    function _revertUnhandledExceptionReason() 
        virtual override internal pure returns (string memory)
    {
        return string(abi.encodePacked(
            type(WitOracleDataLib).name,
            ": unhandled assertion"
        ));
    }

    /// Returns storage pointer to contents of 'WitOracleDataLib.Storage' struct.
    function __storage() virtual internal pure returns (WitOracleDataLib.Storage storage _ptr) {
      return WitOracleDataLib.data();
    }
}
