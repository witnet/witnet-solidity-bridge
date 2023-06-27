// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../../WitnetUpgradableBase.sol";
import "../../../WitnetRequestBoard.sol";
import "../../../data/WitnetBoardData.sol";

/// @title Witnet Request Board "trustable" base implementation contract.
/// @notice Contract to bridge requests to Witnet Decentralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetRequestBoardBypass
    is 
        WitnetBoardData,
        WitnetUpgradableBase
{
    WitnetRequestBoard public immutable bypass;
    WitnetRequestBoard public former;
    uint public offset;

    constructor(
            WitnetRequestBoard _bypass,
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.board"
        )
    {
        assert(address(_bypass) != address(0));
        bypass = _bypass;
    }

    fallback() override external {
        address _bypass = address(bypass);
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := call(gas(), _bypass, 0, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            switch result
                case 0 { revert(ptr, size) }
                default { return(ptr, size) }
        }
    }

    function class() virtual override external pure returns (bytes4) {
        return (
            type(IWitnetRequestBoardDeprecating).interfaceId
                ^ type(IWitnetRequestBoardReporter).interfaceId
                ^ type(IWitnetRequestBoardRequestor).interfaceId
                ^ type(IWitnetRequestBoardView).interfaceId
        );
    }

    /// @notice Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// @notice A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// @notice result to this request.
    /// @dev Fails if:
    /// @dev - provided reward is too low.
    /// @dev - provided script is zero address.
    /// @dev - provided script bytecode is empty.
    /// @param addr The address of the IWitnetRequest contract that can provide the actual Data Request bytecode.
    function postRequest(IWitnetRequest addr)
        external payable
        returns (uint256 _queryId)
    {
        _queryId = offset + bypass.postRequest{value:msg.value, gas: gasleft()}(addr);
    }

    /// @notice Requests the execution of the given Witnet Data Request in expectation that it will be relayed and solved by the Witnet DON.
    /// @notice A reward amount is escrowed by the Witnet Request Board that will be transferred to the reporter who relays back the Witnet-provided 
    /// @notice result to this request.
    /// @dev Fails if, provided reward is too low.
    /// @param radHash The radHash of the Witnet Data Request.
    /// @param slaHash The slaHash of the Witnet Data Request.
    function postRequest(bytes32 radHash, bytes32 slaHash)
        external payable
        returns (uint256 _queryId)
    {
        return offset + bypass.postRequest{value: msg.value, gas: gasleft()}(radHash, slaHash);
    }

    
    // ================================================================================================================
    // --- Overrides 'Upgradeable' -------------------------------------------------------------------------------------

    function owner() virtual override public view returns (address) {
        return __storage().owner;
    }

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory)
        public
        override
    {
        address _owner = __storage().owner;
        if (_owner == address(0)) {
            // set owner if none set yet
            _transferOwnership(msg.sender);
            __proxiable().implementation = base();
            __proxiable().proxy = address(this);
        } else {
            // only owner can initialize:
            require(
                msg.sender == _owner,
                "WitnetRequestBoardBypass: only the owner"
            );
        }
        if (__proxiable().implementation == address(0)) {
            revert("WitnetRequestBoardBypass: cannot bypass zero address");
        } else if (__proxiable().implementation == base()) {
            revert("WitnetRequestBoardBypass: already initialized");
        } else {
            former = WitnetRequestBoard(__proxiable().implementation);
            offset = __storage().numQueries;
        }
        __proxiable().implementation == base();
        emit Upgraded(msg.sender, base(), codehash(), version());
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = owner();
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _owner == _from
        );
    }
}