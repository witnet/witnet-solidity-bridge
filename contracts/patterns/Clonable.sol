// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "./Initializable.sol";

abstract contract Clonable is Initializable {
    address immutable private __self = address(this);

    /// Deploys and returns the address of a minimal proxy clone that replicates contract
    /// behaviour while using its own EVM storage.
    /// @dev This function should always provide a new address, no matter how many times 
    /// @dev is actually called from the same `msg.sender`.
    function clone()
        public virtual
        returns (Clonable _instance)
    {
        address _self = __self;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, _self))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            _instance := create(0, ptr, 0x37)
        }        
        require(address(_instance) != address(0), "Clonable: CREATE failed");
    }

    /// Deploys and returns the address of a minimal proxy clone that replicates contract 
    /// behaviour while using its own EVM storage.
    /// @dev This function uses the CREATE2 opcode and a `_salt` to deterministically deploy
    /// @dev the clone. Using the same `_salt` multiple time will revert, since
    /// @dev the clones cannot be deployed twice at the same address.
    function cloneDeterministic(bytes32 _salt)
        public virtual
        returns (Clonable _instance)
    {
        address _self = __self;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, _self))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            _instance := create2(0, ptr, 0x37, _salt)
        }
        require(address(_instance) != address(0), "Clonable: CREATE2 failed");
    }
}
