// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitnetProxy.sol";
import "../libs/Create3.sol";

/// @notice WitnetDeployer contract used both as CREATE2 (EIP-1014) factory for Witnet artifacts, 
/// @notice and CREATE3 (EIP-3171) factory for Witnet proxies.
/// @author Guillermo Díaz <guillermo@otherplane.com>

contract WitnetDeployer {

    /// @notice Use given `_initCode` and `_salt` to deploy a contract into a deterministic address. 
    /// @dev The address of deployed address will be determined by both the `_initCode` and the `_salt`, but not the address
    /// @dev nor the nonce of the caller (i.e. see EIP-1014). 
    /// @param _initCode Creation code, including construction logic and input parameters.
    /// @param _salt Arbitrary value to modify resulting address.
    /// @return _deployed Just deployed contract address.
    function deploy(bytes memory _initCode, bytes32 _salt)
        virtual public
        returns (address _deployed)
    {
        _deployed = determineAddr(_initCode, _salt);
        if (_deployed.code.length == 0) {
            assembly {
                _deployed := create2(0, add(_initCode, 0x20), mload(_initCode), _salt)
            }
            require(_deployed != address(0), "WitnetDeployer: deployment failed");
        }
    }

    /// @notice Determine counter-factual address of the contract that would be deployed by the given `_initCode` and a `_salt`.
    /// @param _initCode Creation code, including construction logic and input parameters.
    /// @param _salt Arbitrary value to modify resulting address.
    /// @return Deterministic contract address.
    function determineAddr(bytes memory _initCode, bytes32 _salt)
        virtual public view
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

    function determineProxyAddr(bytes32 _salt) 
        virtual public view
        returns (address)
    {
        return Create3.determineAddr(_salt);
    }

    function proxify(bytes32 _proxySalt, address _firstImplementation, bytes memory _initData)
        virtual external 
        returns (WitnetProxy)
    {
        address _proxyAddr = determineProxyAddr(_proxySalt);
        if (_proxyAddr.code.length == 0) {
            // deploy the WitnetProxy
            Create3.deploy(_proxySalt, type(WitnetProxy).creationCode);
            // settle first implementation address,
            WitnetProxy(payable(_proxyAddr)).upgradeTo(
                _firstImplementation, 
                // and initialize it, providing
                abi.encode(
                    // the owner (i.e. the caller of this function)
                    msg.sender,
                    // and some (optional) initialization data
                     _initData
                )
            );
            return WitnetProxy(payable(_proxyAddr));
        } else {
            revert("WitnetDeployer: already proxified");
        }
    }

}