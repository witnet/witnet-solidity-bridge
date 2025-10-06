// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20 <0.9.0;

import "./Initializable.sol";

abstract contract Clonable2
    is
        Initializable
{
    address immutable internal __SELF = address(this);

    event Cloned(address indexed by, address indexed master, address indexed clone);

    modifier onlyOnClones virtual {
        require(cloned(), "Clonable2: only on clones");
        _;
    }

    modifier notOnClones virtual {
        require(!cloned(), "Clonable2: not on clones"); 
        _;
    }

    modifier wasInitialized {
        require(initialized(), "Clonable2: not initialized");
        _;
    }

    function base() virtual public view returns (address) {
        return __SELF;
    }

    /// @notice Tells whether this contract is a clone of `self()`
    function cloned()
        virtual public view
        returns (bool)
    {
        return address(this) != __SELF;
    }

    /// @notice Tells whether this instance has been initialized.
    function initialized() virtual public view returns (bool);

    /// @notice Master address from which this contract was cloned.
    function master() virtual public view returns (address) {
        return __clonable2().master;
    }

    /// @notice Contract address to which clones will be re-directed.
    function target() virtual public view returns (address) {
        return cloned() ? address(0) : __SELF;
    }

    /// Virtual method to be called upon new cloned instances.
    function __initializeClone(address _master) virtual internal {
        __clonable2().master = _master; 
    }

    /// Deploys and returns the address of a minimal proxy clone that replicates contract
    /// behaviour while using its own EVM storage.
    /// @dev This function should always provide a new address, no matter how many times 
    /// @dev is actually called from the same `msg.sender`.
    /// @dev See https://eips.ethereum.org/EIPS/eip-1167.
    /// @dev See https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract/.
    function __clone()
        internal
        returns (address _instance)
    {
        bytes memory ptr = _cloneBytecodePtr();
        assembly {
            // CREATE new instance:
            _instance := create(0, ptr, 0x37)
        }        
        require(_instance != address(0), "Clonable2: CREATE failed");
        emit Cloned(msg.sender, target(), _instance);
    }

    /// Deploys and returns the address of a minimal proxy clone that replicates contract 
    /// behaviour while using its own EVM storage.
    /// @dev This function uses the CREATE2 opcode and a `_salt` to deterministically deploy
    /// @dev the clone. Using the same `_salt` multiple times will revert, since
    /// @dev no contract can be deployed more than once at the same address.
    /// @dev See https://eips.ethereum.org/EIPS/eip-1167.
    /// @dev See https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract/.
    function __cloneDeterministic(bytes32 _salt)
        internal
        notOnClones
        returns (address _instance)
    {
        bytes memory ptr = _cloneBytecodePtr();
        assembly {
            // CREATE2 new instance:
            _instance := create2(0, ptr, 0x37, _salt)
        }
        require(_instance != address(0), "Clonable2: CREATE2 failed");
        emit Cloned(msg.sender, target(), _instance);
    }

    /// @notice Returns minimal proxy's deploy bytecode.
    function _cloneBytecode()
        private view
        returns (bytes memory)
    {
        return abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            bytes20(target()),
            hex"5af43d82803e903d91602b57fd5bf3"
        );
    }

    /// @notice Returns mem pointer to minimal proxy's deploy bytecode.
    function _cloneBytecodePtr()
        private view
        returns (bytes memory ptr)
    {
        address _target = target();
        assembly {
            // ptr to free mem:
            ptr := mload(0x40)
            // begin minimal proxy construction bytecode:
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            // make minimal proxy delegate all calls to `target()`:
            mstore(add(ptr, 0x14), shl(0x60, _target))
            // end minimal proxy construction bytecode:
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
        }
    }

    struct Storage {
        address master;
    }

    function __clonable2() internal pure returns (Storage storage clonable) {
        assembly {
            // bytes32(uint256(keccak256('eip1967.clonable.master')) & ~bytes32(uint256(0xff)
            clonable.slot := 0x033dcaf396f361642869bf1bdf9c3454888f3e9bbf7939acdd2e40c3833fef00
        }
    }
}