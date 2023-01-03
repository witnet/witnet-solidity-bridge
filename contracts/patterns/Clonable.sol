// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "./Initializable.sol";

abstract contract Clonable
    is
        Initializable
{
    address immutable internal _SELF = address(this);

    event Cloned(address indexed by, Clonable indexed self, Clonable indexed clone);

    /// Tells whether this contract is a clone of `self()`
    function cloned()
        public view
        returns (bool)
    {
        return (
            address(this) != self()
        );
    }

    /// Deploys and returns the address of a minimal proxy clone that replicates contract
    /// behaviour while using its own EVM storage.
    /// @dev This function should always provide a new address, no matter how many times 
    /// @dev is actually called from the same `msg.sender`.
    /// @dev See https://eips.ethereum.org/EIPS/eip-1167.
    /// @dev See https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract/.
    function clone()
        public virtual
        returns (Clonable _instance)
    {
        address _base = self();
        assembly {
            // ptr to free mem:
            let ptr := mload(0x40)
            // begin minimal proxy construction bytecode:
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            // make minimal proxy delegate all calls to `self()`:
            mstore(add(ptr, 0x14), shl(0x60, _base))
            // end minimal proxy construction bytecode:
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            // CREATE new instance:
            _instance := create(0, ptr, 0x37)
        }        
        require(
            address(_instance) != address(0),
            "Clonable: CREATE failed"
        );
        emit Cloned(
            msg.sender,
            Clonable(self()),
            _instance
        );
    }

    /// Deploys and returns the address of a minimal proxy clone that replicates contract 
    /// behaviour while using its own EVM storage.
    /// @dev This function uses the CREATE2 opcode and a `_salt` to deterministically deploy
    /// @dev the clone. Using the same `_salt` multiple times will revert, since
    /// @dev no contract can be deployed more than once at the same address.
    /// @dev See https://eips.ethereum.org/EIPS/eip-1167.
    /// @dev See https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract/.
    function cloneDeterministic(bytes32 _salt)
        public virtual
        returns (Clonable _instance)
    {
        address _base = self();
        assembly {
            // ptr to free mem:
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            // make minimal proxy delegate all calls to `self()`:
            mstore(add(ptr, 0x14), shl(0x60, _base))
            // end minimal proxy construction bytecode:
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            // CREATE2 new instance:
            _instance := create2(0, ptr, 0x37, _salt)
        }
        require(
            address(_instance) != address(0),
            "Clonable: CREATE2 failed"
        );
        emit Cloned(msg.sender, Clonable(self()), _instance);
    }

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.    
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory) virtual external;

    /// @notice Contract address to which clones will be re-directed.
    function self() virtual public view returns (address) {
        return _SELF;
    }
}
