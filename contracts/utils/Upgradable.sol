// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "./Initializable.sol";
import "./Proxiable.sol";

abstract contract Upgradable is Initializable, Proxiable {

    address internal immutable __base;
    bytes32 internal immutable __codehash;
    bool internal immutable __upgradable;

    constructor (bool _isUpgradable) {
        address _base = address(this);
        bytes32 _codehash;        
        assembly {
            _codehash := extcodehash(_base)
        }
        __base = _base;
        __codehash = _codehash;        
        __upgradable = _isUpgradable;
    }

    /// @dev Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address from) virtual external view returns (bool);


    /// TODO: the following methods should be all declared as pure 
    ///       whenever this Solidity's PR gets merged and released: 
    ///       https://github.com/ethereum/solidity/pull/10240

    /// @dev Retrieves base contract. Differs from address(this) when via delegate-proxy pattern.
    function base() public view returns (address) {
        return __base;
    }

    /// @dev Retrieves the immutable codehash of this contract, even if invoked as delegatecall.
    /// @return _codehash This contracts immutable codehash.
    function codehash() public view returns (bytes32 _codehash) {
        return __codehash;
    }
    
    /// @dev Determines whether current instance allows being upgraded.
    /// @dev Returned value should be invariant from whoever is calling.
    function isUpgradable() public view returns (bool) {        
        return __upgradable;
    }

    /// @dev Retrieves human-redable named version of current implementation.
    function version() virtual public view returns (bytes32); 
}