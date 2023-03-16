// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

/// @title Based on Singleton Factory (EIP-2470), authored by Guilherme Schmidt (Status Research & Development GmbH)
/// @notice Exposes CREATE2 (EIP-1014) to deploy bytecode on deterministic addresses based on initialization code and salt.
/// @dev Exposes also helper method to pre-determine contract address gieve
/// @author Ricardo Guilherme Schmidt (Status Research & Development GmbH)

contract Create2Factory {

    /// @notice Deploys `_initCode` using `_salt` for defining the deterministic address.
    /// @param _initCode Initialization code.
    /// @param _salt Arbitrary value to modify resulting address.
    /// @return createdContract Created contract address.
    function deploy(bytes memory _initCode, bytes32 _salt)
        public
        returns (address payable createdContract)
    {
        assembly {
            createdContract := create2(0, add(_initCode, 0x20), mload(_initCode), _salt)
        }
    }

    /// @notice Determine singleton contract address that might be created from this factory, given its `_initCode` and a `_salt`.
    /// @param _initCode Initialization code.
    /// @param _salt Arbitrary value to modify resulting address.
    /// @return expectedAddr Expected contract address.
    function determineAddr(bytes memory _initCode, bytes32 _salt)
        public
        view
        returns (address)
    {
        return address(
            uint160(uint(keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(this),
                    _salt,
                    keccak256(_initCode)
                )
            )))
        );
    }

}