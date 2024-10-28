// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract IWitAppliance {

    /// @notice Returns the name of the actual contract implementing the logic of this Witnet appliance.
    function class() virtual public view returns (string memory);

    /// @notice Returns the ERC-165 id of the minimal functionality expected for this appliance.
    function specs() virtual external view returns (bytes4);

    function _require(bool _condition, string memory _message) virtual internal view {
        if (!_condition) {
            _revert(_message);
        }
    }

    function _revert(string memory _message) virtual internal view {
        revert(
            string(abi.encodePacked(
                class(),
                ": ",
                _message
            ))
        );
    }

}
