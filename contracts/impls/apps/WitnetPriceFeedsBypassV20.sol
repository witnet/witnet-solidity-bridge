// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../impls/WitnetUpgradableBase.sol";
import "../../interfaces/V2/IWitnetPriceFeeds.sol";

abstract contract WitnetPriceFeedsV07 {
    function supportedFeeds() virtual external view returns (bytes4[] memory, string[] memory, bytes32[] memory);
}

abstract contract WitnetPriceFeedsV20 {
    function isUpgradableFrom(address) virtual external view returns (bool);
    function latestUpdateResponseStatus(bytes4) virtual external view returns (WitnetV2.ResponseStatus);
    function owner() virtual external view returns (address);
    function requestUpdate(bytes4) virtual external payable returns (uint256);
    function specs() virtual external view returns (bytes4);
}

/// @title Witnet Price Feeds surrogate bypass implementation to V2.0 
/// @author The Witnet Foundation
contract WitnetPriceFeedsBypassV20
    is
        WitnetUpgradableBase
{
    using Witnet for bytes4;
    using WitnetV2 for WitnetV2.RadonSLA;

    WitnetPriceFeedsV20 immutable public surrogate;

    constructor (
            WitnetPriceFeedsV20 _surrogate,
            bool _upgradable,
            bytes32 _versionTag
        )
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.router"
        )
    {
        _require(
            address(_surrogate).code.length > 0
                && _surrogate.specs() == type(IWitnetPriceFeeds).interfaceId,
            "uncompliant surrogate"
        );
        surrogate = _surrogate;
    }

    // solhint-disable-next-line payable-fallback
    fallback() virtual override external { /* solhint-disable no-complex-fallback */
        address _surrogate = address(surrogate);
        assembly { /* solhint-disable avoid-low-level-calls */
            // Gas optimized surrogate call to the 'surrogate' immutable contract.
            // Note: `msg.data`, `msg.sender` and `msg.value` will be passed over 
            //       to actual implementation of `msg.sig` within `implementation` contract.
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := call(gas(), _surrogate, 0, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            switch result
                case 0  { 
                    // pass back revert message:
                    revert(ptr, size) 
                }
                default {
                  // pass back same data as returned by 'implementation' contract:
                  return(ptr, size) 
                }
        }
    }

    function class() public pure returns (string memory) {
        return type(WitnetPriceFeedsBypassV20).name;
    }

    
    // ================================================================================================================
    // --- Overrides 'Upgradeable' -------------------------------------------------------------------------------------

    function owner() public view override returns (address) {
        return surrogate.owner();
    }
   
    
    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    /// @dev Must fail when trying to upgrade to same logic contract more than once.
    function initialize(bytes memory) 
        public override
        onlyDelegateCalls // => we don't want the logic base contract to be ever initialized
    {
        if (
            __proxiable().proxy == address(0)
                && __proxiable().implementation == address(0)
        ) {
            // a proxy is being initialized for the first time...
            __proxiable().proxy = address(this);
            _transferOwnership(msg.sender);
        } else {
            // only the owner can initialize:
            if (msg.sender != owner()) {
                _revert("not the owner");
            }
        }
        
        // Check that new implentation hasn't actually been initialized already:
        _require(
            __proxiable().implementation != base(),
            "already initialized"
        );
        
        (bytes4[] memory _id4s,,) = WitnetPriceFeedsV07(address(this)).supportedFeeds();
        for (uint _ix = 0; _ix < _id4s.length; _ix ++) {
            // Check that all supported price feeds under current implementation
            // are actually supported under the surrogate immutable instance,
            // and that none of them is currently in pending status:
            WitnetV2.ResponseStatus _status = surrogate.latestUpdateResponseStatus(_id4s[_ix]);
            _require(
                _status == WitnetV2.ResponseStatus.Ready 
                    || _status == WitnetV2.ResponseStatus.Error
                    || _status == WitnetV2.ResponseStatus.Delivered,
                string(abi.encodePacked(
                    "unconsolidated feed: 0x",
                    _id4s[_ix].toHexString()
                ))
            );
        }

        // Set new implementation as initialized:
        __proxiable().implementation = base();

        // Emit event:
        emit Upgraded(msg.sender, base(), codehash(), version());
    }

    function isUpgradableFrom(address _from) external view override returns (bool) {
        return surrogate.isUpgradableFrom(_from);
    }


    // ================================================================================================================
    // --- Partial interception of 'IWitnetFeeds' ---------------------------------------------------------------------

    function defaultRadonSLA() 
        public view
        returns (Witnet.RadonSLA memory)
    {
        return abi.decode(
            _staticcall(abi.encodeWithSignature(
                "defaulRadonSLA()"
            )),
            (WitnetV2.RadonSLA)
        ).toV1();
    }

    function estimateUpdateBaseFee(bytes4, uint256 _gasPrice, uint256) public view returns (uint256) {
        return abi.decode(
            _staticcall(abi.encodeWithSignature(
                "estimateUpdateUpdateRequestFee(uint256)", 
                _gasPrice
            )),
            (uint256)
        );
    }

    function estimateUpdateBaseFee(bytes4, uint256 _gasPrice, uint256, bytes32) external view returns (uint256) {
        return abi.decode(
            _staticcall(abi.encodeWithSignature(
                "estimateUpdateUpdateRequestFee(uint256)", 
                _gasPrice
            )),
            (uint256)
        );
    }

    function latestResponse(bytes4 _feedId) public view returns (Witnet.Response memory) {
        WitnetV2.Response memory _responseV2 = abi.decode(
            _staticcall(abi.encodeWithSignature(
                "lastValidResponse(bytes4)",
                _feedId
            )),
            (WitnetV2.Response)
        );
        return Witnet.Response({
            reporter: _responseV2.reporter,
            timestamp: uint256(_responseV2.resultTimestamp),
            drTxHash: _responseV2.resultTallyHash,
            cborBytes: _responseV2.resultCborBytes
        });
    }

    function latestResult(bytes4 _feedId) public view returns (Witnet.Result memory) {
        return Witnet.resultFromCborBytes(
            latestResponse(_feedId).cborBytes
        );
    }

    function latestUpdateRequest(bytes4 _feedId) external view returns (Witnet.Request memory) {
        WitnetV2.Request memory _requestV2 = abi.decode(
            _staticcall(abi.encodeWithSignature(
                "latestUpdateRequest(bytes4)", 
                _feedId
            )),
            (WitnetV2.Request)
        );
        return Witnet.Request({
            addr: address(0),
            slaHash: abi.decode(abi.encode(_requestV2.witnetSLA), (bytes32)),
            radHash: _requestV2.witnetRAD,
            gasprice: tx.gasprice,
            reward: uint256(_requestV2.evmReward)
        });
    }
    
    function latestUpdateResponse(bytes4 _feedId) external view returns (Witnet.Response memory) {
        WitnetV2.Response memory _responseV2 = abi.decode(
            _staticcall(abi.encodeWithSignature(
                "latestUpdateResponse(bytes4)", 
                _feedId
            )),
            (WitnetV2.Response)
        );
        return Witnet.Response({
            reporter: _responseV2.reporter,
            timestamp: uint256(_responseV2.resultTimestamp),
            drTxHash: bytes32(_responseV2.resultTallyHash),
            cborBytes: _responseV2.resultCborBytes
        });
    }
    
    function latestUpdateResultStatus(bytes4 _feedId) external view returns (Witnet.ResultStatus) {
        WitnetV2.ResponseStatus _status = abi.decode(
            _staticcall(abi.encodeWithSignature(
                "latestUpdateResponseStatus(bytes4)", 
                _feedId
            )),
            (WitnetV2.ResponseStatus)
        );
        if (_status == WitnetV2.ResponseStatus.Finalizing) {
            return Witnet.ResultStatus.Awaiting;
        } else {
            return Witnet.ResultStatus(uint8(_status));
        }
    }

    function lookupBytecode(bytes4 _feedId) external view returns (bytes memory) {
        return abi.decode(
            _staticcall(abi.encodeWithSignature(
                "lookupWitnetBytecode(bytes4)", 
                _feedId
            )),
            ((bytes))
        );
    }
    
    function lookupRadHash(bytes4 _feedId) external view returns (bytes32) {
        return abi.decode(
            _staticcall(abi.encodeWithSignature(
                "lookupWitnetRadHash(bytes4)", 
                _feedId
            )),
            (bytes32)
        );
    }

    function requestUpdate(bytes4 _feedId) external payable returns (uint256 _usedFunds) {
        _usedFunds = surrogate.requestUpdate{
            value: msg.value
        }(
            _feedId
        );
        if (_usedFunds < msg.value) {
            // transfer back unused funds:
            payable(msg.sender).transfer(msg.value - _usedFunds);
        }
    }
    
    function requestUpdate(bytes4, bytes32) external payable returns (uint256) {
        _revert("deprecated");
    }


    // ================================================================================================================
    // --- Partial interception of 'IWitnetFeedsAdmin' ----------------------------------------------------------------

    function settleDefaultRadonSLA(Witnet.RadonSLA calldata _slaV1) external {
        _require(
            Witnet.isValid(_slaV1),
            "invalid SLA"
        );
        __call(abi.encodeWithSignature(
            "settleDefaultRadonSLA((uint8,uint64))", 
            WitnetV2.RadonSLA({
                committeeSize: _slaV1.numWitnesses,
                witnessingFeeNanoWit: _slaV1.witnessCollateral / _slaV1.numWitnesses
            })
        ));
    }

    
    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function _require(bool _condition, string memory _message) internal pure {
        if (!_condition) {
            _revert(_message);
        }
    }

    function _revert(string memory _reason) internal pure {
        revert(
            string(abi.encodePacked(
                class(),
                ": ",
                _reason
            ))
        );
    }

    function _staticcall(bytes memory _encodedCall) internal view returns (bytes memory _returnData) {
        bool _success;
        (_success, _returnData) = address(surrogate).staticcall(_encodedCall);
        _require(
            _success,
            string(abi.encodePacked(
                "cannot surrogate static call: 0x",
                msg.sig.toHexString()
            ))
        );
    }

    function __call(bytes memory _encodedCall) internal returns (bytes memory _returnData) {
        bool _success;
        (_success, _returnData) = address(surrogate).call(_encodedCall);
        _require(
            _success,
            string(abi.encodePacked(
                "cannot surrogate call: 0x",
                msg.sig.toHexString()
            ))
        );
    }

}