// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "./Initializable.sol";

abstract contract Upgradable is Initializable {
    address internal immutable __stub;

    event Initialized(address indexed from, address stub);

    constructor () {
        __stub = address(this);
    }

    /// @dev Retrieves the immutable codehash of this instance, even if invoked as delegatecall.
    /// @return _codehash This contracts immutable codehash.
    function codehash() external view returns (bytes32 _codehash) {
        address _stub = __stub;
        assembly {
            _codehash := extcodehash(_stub)
        }
    }
    
    /// @dev Determines whether current instance allows being upgraded.
    /// @dev Returned value should be invariant from whoever is calling.
    function isUpgradable() virtual external view returns (bool) {
        // TODO: should be declared as pure whenever this Solidity's PR 
        //       gets merged and released: https://github.com/ethereum/solidity/pull/10240
        return true;
    }

    /// @dev Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address from) virtual external view returns (bool);

    /// @dev Retrieves named version of current implementation.
    function version() virtual external view returns (string memory);
}