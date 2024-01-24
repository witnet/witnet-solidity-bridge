// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

/// @notice Deploy to deterministic addresses without an initcode factor.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/CREATE3.sol)
/// @author 0xSequence (https://github.com/0xSequence/create3/blob/master/contracts/Create3.sol)

library Create3 {

    //--------------------------------------------------------------------------------//
    // Opcode     | Opcode + Arguments    | Description      | Stack View             //
    //--------------------------------------------------------------------------------//
    // 0x36       |  0x36                 | CALLDATASIZE     | size                   //
    // 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 size                 //
    // 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 0 size               //
    // 0x37       |  0x37                 | CALLDATACOPY     |                        //
    // 0x36       |  0x36                 | CALLDATASIZE     | size                   //
    // 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 size                 //
    // 0x34       |  0x34                 | CALLVALUE        | value 0 size           //
    // 0xf0       |  0xf0                 | CREATE           | newContract            //
    //--------------------------------------------------------------------------------//
    // Opcode     | Opcode + Arguments    | Description      | Stack View             //
    //--------------------------------------------------------------------------------//
    // 0x67       |  0x67XXXXXXXXXXXXXXXX | PUSH8 bytecode   | bytecode               //
    // 0x3d       |  0x3d                 | RETURNDATASIZE   | 0 bytecode             //
    // 0x52       |  0x52                 | MSTORE           |                        //
    // 0x60       |  0x6008               | PUSH1 08         | 8                      //
    // 0x60       |  0x6018               | PUSH1 18         | 24 8                   //
    // 0xf3       |  0xf3                 | RETURN           |                        //
    //--------------------------------------------------------------------------------//
    
    bytes internal constant CREATE3_FACTORY_BYTECODE = hex"67_36_3d_3d_37_36_3d_34_f0_3d_52_60_08_60_18_f3";
    bytes32 internal constant CREATE3_FACTORY_CODEHASH = keccak256(CREATE3_FACTORY_BYTECODE);

    /// @notice Creates a new contract with given `_creationCode` and `_salt`
    /// @param _salt Salt of the contract creation, resulting address will be derivated from this value only
    /// @param _creationCode Creation code (constructor) of the contract to be deployed, this value doesn't affect the resulting address
    /// @return addr of the deployed contract, reverts on error
    function deploy(bytes32 _salt, bytes memory _creationCode)
        internal 
        returns (address)
    {
        return deploy(_salt, _creationCode, 0);
    }

    /// @notice Creates a new contract with given `_creationCode`, `_salt` and `_value`. 
    /// @param _salt Salt of the contract creation, resulting address will be derivated from this value only
    /// @param _creationCode Creation code (constructor) of the contract to be deployed, this value doesn't affect the resulting address
    /// @param _value In WEI of ETH to be forwarded to child contract
    /// @return _deployed The address of the deployed contract.
    function deploy(bytes32 _salt, bytes memory _creationCode, uint256 _value)
        internal
        returns (address _deployed)
    {
        // Get target final address
        _deployed = determineAddr(_salt);
        if (_deployed.code.length != 0) revert("Create3: target already exists");

        // Create factory
        address _factory;
        bytes memory _factoryBytecode = CREATE3_FACTORY_BYTECODE;
        /// @solidity memory-safe-assembly
        assembly {
            // Deploy a factory contract with our pre-made bytecode via CREATE2.
            // We start 32 bytes into the code to avoid copying the byte length.
            _factory := create2(0, add(_factoryBytecode, 32), mload(_factoryBytecode), _salt)
        }
        require(_factory != address(0), "Create3: error creating factory");       

        // Use factory to deploy target
        (bool _success, ) = _factory.call{value: _value}(_creationCode);
        require(_success && _deployed.code.length != 0, "Create3: error creating target");
    }

    /// @notice Computes the resulting address of a contract deployed using address(this) and the given `_salt`
    /// @param _salt Salt of the contract creation, resulting address will be derivated from this value only
    /// @return addr of the deployed contract, reverts on error
    /// @dev The address creation formula is: keccak256(rlp([keccak256(0xff ++ address(this) ++ _salt ++ keccak256(childBytecode))[12:], 0x01]))
    function determineAddr(bytes32 _salt) internal view returns (address) {
        address _factory = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            address(this),
                            _salt,
                            CREATE3_FACTORY_CODEHASH
                        )
                    )
                )
            )
        );
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            // 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ _factory ++ 0x01)
                            // 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex)
                            hex"d6_94",
                            _factory,
                            // _factory's nonce on which the target is created: 0x1
                            hex"01"
                        )
                    )
                )
            )
        );
    }

}