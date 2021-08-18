// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.6.0 <0.9.0;

import "./Initializable.sol";
import "./Proxiable.sol";

abstract contract Upgradable is Initializable, Proxiable {

    address internal immutable _BASE;
    bytes32 internal immutable _CODEHASH;
    bool internal immutable _UPGRADABLE;

    /// Emitted every time the contract gets upgraded.
    /// @param from The address who ordered the upgrading. Namely, the WRB operator in "trustable" implementations.
    /// @param baseAddr The address of the new implementation contract.
    /// @param baseCodehash The EVM-codehash of the new implementation contract.
    /// @param versionTag Ascii-encoded version literal with which the implementation deployer decided to tag it.
    event Upgraded(
        address indexed from,
        address indexed baseAddr,
        bytes32 indexed baseCodehash,
        bytes32 versionTag
    );

    constructor (bool _isUpgradable) {
        address _base = address(this);
        bytes32 _codehash;        
        assembly {
            _codehash := extcodehash(_base)
        }
        _BASE = _base;
        _CODEHASH = _codehash;        
        _UPGRADABLE = _isUpgradable;
    }

    /// @dev Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address from) virtual external view returns (bool);


    /// TODO: the following methods should be all declared as pure 
    ///       whenever this Solidity's PR gets merged and released: 
    ///       https://github.com/ethereum/solidity/pull/10240

    /// @dev Retrieves base contract. Differs from address(this) when via delegate-proxy pattern.
    function base() public view returns (address) {
        return _BASE;
    }

    /// @dev Retrieves the immutable codehash of this contract, even if invoked as delegatecall.
    /// @return _codehash This contracts immutable codehash.
    function codehash() public view returns (bytes32 _codehash) {
        return _CODEHASH;
    }
    
    /// @dev Determines whether current instance allows being upgraded.
    /// @dev Returned value should be invariant from whoever is calling.
    function isUpgradable() public view returns (bool) {        
        return _UPGRADABLE;
    }

    /// @dev Retrieves human-redable named version of current implementation.
    function version() virtual public view returns (bytes32); 
}