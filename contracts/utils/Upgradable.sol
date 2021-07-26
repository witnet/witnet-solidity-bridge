// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "./Initializable.sol";

abstract contract Upgradable is Initializable {

    address internal immutable __base;
    bytes32 internal immutable __codehash;
    bool internal immutable __upgradable;

    constructor (bool _upgradable) {
        address _base = address(this);
        bytes32 _codehash;        
        assembly {
            _codehash := extcodehash(_base)
        }
        __base = _base;
        __codehash = _codehash;        
        __upgradable = _upgradable;
    }

    /// @dev Retrieves base contract. Differs from address(this) when via delegate-proxy pattern.
    function base() public view returns (address) {
        // TODO: should be declared as pure whenever this Solidity's PR 
        //       gets merged and released: https://github.com/ethereum/solidity/pull/10240
        return __base;
    }

    /// @dev Retrieves the immutable codehash of this contract, even if invoked as delegatecall.
    /// @return _codehash This contracts immutable codehash.
    function codehash() public view returns (bytes32 _codehash) {
        // TODO: should be declared as pure whenever this Solidity's PR 
        //       gets merged and released: https://github.com/ethereum/solidity/pull/10240
        return __codehash;
    }
    
    /// @dev Determines whether current instance allows being upgraded.
    /// @dev Returned value should be invariant from whoever is calling.
    function isUpgradable() public view returns (bool) {
        // TODO: should be declared as pure whenever this Solidity's PR 
        //       gets merged and released: https://github.com/ethereum/solidity/pull/10240
        return __upgradable;
    }

    /// @dev Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address from) virtual external view returns (bool);

    /// @dev Retrieves named version of current implementation.
    function version() virtual external pure returns (string memory);
}