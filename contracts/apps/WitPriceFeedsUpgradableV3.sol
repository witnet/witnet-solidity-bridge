// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./WitPriceFeedsV3.sol";
import "../patterns/Upgradeable.sol";

/// @title WitPriceFeedsUpgradableV3: On-demand Price Feeds registry for EVM-compatible L1/L2 chains, 
/// natively powered by the Wit/Oracle blockchain, but yet capable of aggregating price 
/// updates from other on-chain price-feed oracles too, if required.
/// 
/// Price feeds purely relying on the Wit/Oracle present some advantanges, though:
/// - Anyone can permissionless pull and report price updates on-chain.
/// - Updating the price requires paying no extra "update fees".
/// - Prices can be extracted from independent and highly reputed exchanges and data providers.
/// - Actual data sources for each price feed can be introspected on-chain.
/// - Data source traceability in the Wit/Oracle blockchain is possible for every single price update.
///
/// Instances of this contract may also provide support for "routed price feeds" (computed as the 
/// product or mean average of up to other 8 different price feeds), as well as "cascade price feeds" 
/// (where multiple oracles could be used as backup when preferred ones don't manage to provide 
/// fresh enough updates for whatever reason).
///
/// Last but not least, this contract allows simple plug-and-play integration from 
/// smart contracts, dapps and DeFi projects currently adapted to operate with
/// other price feed solutions, like Chainlink, or Pyth. 
///
/// @author Guillermo Díaz <guillermo@witnet.io>

contract WitPriceFeedsUpgradableV3
    is
        Upgradeable,
        WitPriceFeedsV3
{
    bytes32 internal immutable __VERSION;

    function class() virtual override public pure returns (string memory) {
        return type(WitPriceFeedsUpgradableV3).name;
    }

    constructor(
            address _witOracle,
            bytes32 _versionTag,
            bool _upgradable
        )
        Upgradeable(_upgradable)
        WitPriceFeedsV3(_witOracle, msg.sender)
    {
        __VERSION = _versionTag;
        proxiableUUID = keccak256(bytes("io.witnet.pricefeeds.v3"));
    }

    /// @dev Reverts if proxy delegatecalls to unexistent method.
    /* solhint-disable no-complex-fallback */
    fallback() virtual external { 
        _revert(string(abi.encodePacked(
            "not implemented: 0x",
            _toHexString(uint8(bytes1(msg.sig))),
            _toHexString(uint8(bytes1(msg.sig << 8))),
            _toHexString(uint8(bytes1(msg.sig << 16))),
            _toHexString(uint8(bytes1(msg.sig << 24)))
        )));
    }


    /// ===============================================================================================================
    /// --- Clonable2 -------------------------------------------------------------------------------------------------

    function cloned() 
        virtual override 
        public view 
        returns (bool)
    {
        return (
            address(this) != __SELF
                && address(this) != __proxiable().proxy
        );
    }

    function target()
        virtual override
        public view
        returns (address)
    {
        return (__proxiable().proxy != address(0)
            ? __proxiable().proxy 
            : __SELF
        );
    }


    // ================================================================================================================
    // --- Overrides 'Proxiable' --------------------------------------------------------------------------------------

    /// @dev Gets immutable "heritage blood line" (ie. genotype) as a Proxiable, and eventually Upgradeable, contract.
    ///      If implemented as an Upgradeable touch, upgrading this contract to another one with a different 
    ///      `proxiableUUID()` value should fail.
    bytes32 public immutable override proxiableUUID;

    
    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory _initData) virtual override public {
        address _owner = owner();
        if (_owner == address(0)) {
            // upon first upgrade, extract decode owner address from _intidata
            (_owner, _initData) = abi.decode(_initData, (address, bytes));
            _transferOwnership(_owner);
        
        } else {
            // only owner can initialize an existing proxy:
            require(msg.sender == _owner, "not the owner");
        }
        if (
            __proxiable().codehash != bytes32(0)
                && __proxiable().codehash == codehash()
        ) {
            revert("already initialized");
        }
        if (__proxiable().proxy == address(0)) {
            // a proxy is being initialized for the first time...
            __proxiable().proxy = address(this);   
        }
        __proxiable().codehash = codehash();
        __proxiable().implementation = base();
        __initializeUpgradableData(_initData);
        emit Upgraded(owner(), base(), codehash(), version());
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) 
        virtual override
        external view  
        notOnClones 
        returns (bool)
    {
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && owner() == _from
        );
    }

    function version() public view virtual override returns (string memory) {
        return _toString(__VERSION);
    }

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    function __initializeUpgradableData(bytes memory)
        virtual override 
        notOnClones
        internal
    {
        if (
            __proxiable().codehash == bytes32(0)
                || !_validateUpdateConditions(__storage().defaultUpdateConditions)
        ) {
            __storage().defaultUpdateConditions = IWitPriceFeeds.UpdateConditions({
                callbackGas: 1_000_000,
                computeEma: false,
                cooldownSecs: 15 minutes,
                heartbeatSecs: 1 days,
                maxDeviation1000: 250, // 25.0 %
                minWitnesses: 3
            });
        }
    }

    function _toHexString(uint8 _u)
        private pure
        returns (string memory)
    {
        bytes memory b2 = new bytes(2);
        uint8 d0 = uint8(_u / 16) + 48;
        uint8 d1 = uint8(_u % 16) + 48;
        if (d0 > 57)
            d0 += 7;
        if (d1 > 57)
            d1 += 7;
        b2[0] = bytes1(d0);
        b2[1] = bytes1(d1);
        return string(b2);
    }
    
    /// Converts bytes32 into string.
    function _toString(bytes32 _bytes32)
        internal pure
        returns (string memory)
    {
        bytes memory _bytes = new bytes(_toStringLength(_bytes32));
        for (uint _i = 0; _i < _bytes.length;) {
            _bytes[_i] = _bytes32[_i];
            unchecked {
                _i ++;
            }
        }
        return string(_bytes);
    }

    // Calculate length of string-equivalent to given bytes32.
    function _toStringLength(bytes32 _bytes32)
        internal pure
        returns (uint _length)
    {
        for (; _length < 32; ) {
            if (_bytes32[_length] == 0) {
                break;
            }
            unchecked {
                _length ++;
            }
        }
    }
}
