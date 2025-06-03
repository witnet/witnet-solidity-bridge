// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitnetDeployer.sol";

/// @notice WitnetDeployerMeter contract used both as CREATE2 factory (EIP-1014) for Witnet artifacts, 
/// @notice and CREATE3 factory (EIP-3171) for Witnet proxies, on the Meter Ecosystem.
/// @author Guillermo Díaz <guillermo@witnet.io>

contract WitnetDeployerMeter is WitnetDeployer {

    function determineProxyAddr(bytes32 _salt) 
        virtual override
        public view
        returns (address)
    {
        return determineAddr(type(WitnetProxy).creationCode, _salt);
    }

    function proxify(bytes32 _proxySalt, address _firstImplementation, bytes memory _initData)
        virtual override
        external 
        returns (WitnetProxy)
    {
        address _proxyAddr = determineProxyAddr(_proxySalt);
        if (_proxyAddr.code.length == 0) {
            // deploy the WitnetProxy
            deploy(type(WitnetProxy).creationCode, _proxySalt);
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
            revert("WitnetDeployerMeter: already proxified");
        }
    }

}