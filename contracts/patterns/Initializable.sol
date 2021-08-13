// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

interface Initializable {
    /// @dev Initialize contract's storage-context.
    /// @dev Should fail when trying to initialize same contract instance more than once.
    function initialize(bytes calldata) external;

    /// @dev Notifies whenever a proxied-instance gets initialized. 
    event Initialized(
        address indexed from,
        address indexed baseAddr,
        bytes32 indexed baseCodehash,
        bytes32 versionTag
    );
}