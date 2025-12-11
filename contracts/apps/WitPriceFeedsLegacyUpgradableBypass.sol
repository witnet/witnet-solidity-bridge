// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IWitOracle, IWitOracleRadonRegistry, Witnet} from "../interfaces/IWitOracle.sol";

import {IWitOracleLegacy} from "../interfaces/legacy/IWitOracleLegacy.sol";
import {IWitPriceFeeds, IWitPriceFeedsTypes, IWitPyth} from "../interfaces/IWitPriceFeeds.sol";
import {
    IWitPriceFeedsLegacy, 
    IWitPriceFeedsLegacySolver,
    IWitOracleRequest, 
    IWitOracleRequestTemplate
} from "../interfaces/legacy/IWitPriceFeedsLegacy.sol";

import {Slices} from "../libs/Slices.sol";
import {Ownable, Ownable2Step} from "../patterns/Ownable2Step.sol";
import {WitnetUpgradableBase} from "../core/WitnetUpgradableBase.sol";
import {WitPriceFeedsLegacyDataLib} from "../data/WitPriceFeedsLegacyDataLib.sol";
import {
    IERC2362, 
    IWitOracleAppliance, 
    IWitPriceFeedsLegacyAdmin, 
    IWitPriceFeedsLegacySolverFactory
} from "../WitPriceFeedsLegacy.sol";


/// @title WitPriceFeeds: Price Feeds upgradable repository reliant on the Wit/Oracle blockchain.
/// @author Guillermo Díaz <guillermo@witnet.io>

contract WitPriceFeedsLegacyUpgradableBypass
    is
        Ownable2Step,
        WitnetUpgradableBase
{
    using Slices for string;
    using Slices for Slices.Slice;

    IWitOracleRadonRegistry immutable public registry;
    IWitPriceFeeds immutable public surrogate;

    struct BypassV2V3 {
        mapping (IWitPriceFeedsTypes.ID4 => bytes4) v2Ids;
        mapping (bytes4 => IWitPriceFeedsTypes.ID4) v3Ids;
    }

    function class() public pure returns (string memory) {
        return type(WitPriceFeedsLegacyUpgradableBypass).name;
    }

    function specs() public pure returns (bytes4) {
        return (
            type(IERC2362).interfaceId
                ^ type(IWitOracleAppliance).interfaceId
                ^ type(IWitPriceFeedsLegacy).interfaceId
                ^ type(IWitPriceFeedsLegacyAdmin).interfaceId
                ^ type(IWitPriceFeedsLegacySolverFactory).interfaceId   
        );
    }
    
    constructor(
            address _surrogate,
            bytes32 _versionTag,
            bool _upgradable
        )
        Ownable(address(msg.sender))
        WitnetUpgradableBase(
            _upgradable,
            _versionTag,
            "io.witnet.proxiable.feeds.price"
        )
    {
        surrogate = IWitPriceFeeds(_surrogate);
        registry = IWitOracleRadonRegistry(
            IWitOracle(
                IWitOracleAppliance(_surrogate).witOracle()
            ).registry()
        );
    }


    // ================================================================================================================
    // --- Overrides 'Upgradeable' ------------------------------------------------------------------------------------

    /// @notice Re-initialize contract's storage context upon a new upgrade from a proxy.
    function __initializeUpgradableData(bytes memory) virtual override internal {
        // uint _length = __legacy().ids.length;
        // for (uint _ix; _ix < _length; ++ _ix) {
        //     // turn legacy captions 'Price-*' into 'Caption.*' ...
        //     bytes4 _v2Id = __legacy().ids[_ix];
        //     string memory _captionV2 = __legacy().records[_v2Id].caption;
        //     Slices.Slice memory _slice = _captionV2.toSlice();
        //     Slices.Slice memory _delim = string("-").toSlice();
        //     string[] memory _parts = new string[](_slice.count(_delim) + 1);
        //     for (uint _px = 0; _px < _parts.length; _px ++) {
        //         _parts[_px] = _slice.split(_delim).toString();
        //     }
        //     string memory _captionV3 = "Crypto.";
        //     for (uint _px = 1; _px < _parts.length; _px ++) {
        //         _captionV3 = string(abi.encodePacked(
        //             _captionV3,
        //             _parts[_px]
        //         ));
        //     }
        //     IWitPriceFeedsTypes.ID4 _v3Id = IWitPriceFeedsTypes.ID4.wrap(bytes4(keccak256(bytes(_captionV3))));
        //     __bypass().v2Ids[_v3Id] = _v2Id;
        //     __bypass().v3Ids[_v2Id] = _v3Id;
        // }
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = owner();
        return (
            // false if the WRB is intrinsically not upgradable, or `_from` is no owner
            isUpgradable()
                && _owner == _from
        );
    }


    // ================================================================================================================
    // --- Implements 'IWitFeeds' -------------------------------------------------------------------------------------

    function estimateUpdateBaseFee(uint256) external pure returns (uint256) {
        return 0;
    }

    function footprint() external view returns (bytes4) {
        return surrogate.footprint();
    }

    function hash(string memory caption) external pure returns (bytes4) {
        return WitPriceFeedsLegacyDataLib.hash(caption);
    }
    
    function lookupCaption(bytes4 feedId)
        public view
        returns (string memory _caption)
    {
        _caption = surrogate.lookupPriceFeedCaption(IWitPriceFeedsTypes.ID4.wrap(feedId));
        if (bytes(_caption).length == 0) {
            return __legacy().records[feedId].caption;
        }
    }

    function supportedFeeds()
        external view
        returns (bytes4[] memory _ids, string[] memory _captions, bytes32[] memory _solvers)
    {
        IWitPriceFeeds.PriceFeedInfo[] memory _pfs = surrogate.lookupPriceFeeds();
        _ids = new bytes4[](_pfs.length);
        _captions = new string[](_pfs.length);
        _solvers = new bytes32[](_pfs.length);
        for (uint _ix; _ix < _pfs.length; ++ _ix) {
            IWitPriceFeedsTypes.ID4 _v3Id = IWitPriceFeedsTypes.ID4.wrap(bytes4((IWitPyth.ID.unwrap(_pfs[_ix].id))));
            _ids[_ix] = (__bypass().v2Ids[_v3Id] == bytes4(0) ? IWitPriceFeedsTypes.ID4.unwrap(_v3Id) : __bypass().v2Ids[_v3Id]);
            _captions[_ix] = _pfs[_ix].symbol;
            if (_pfs[_ix].mapper.class != IWitPriceFeedsTypes.Mappers.None) {
                _solvers[_ix] = (_pfs[_ix].oracle.sources != bytes32(0)
                    ? _pfs[_ix].oracle.sources
                    : bytes32(bytes20(_pfs[_ix].oracle.target))
                );
            }
        }
    }
    
    function supportsCaption(string calldata caption) external view returns (bool) {
        return surrogate.supportsCaption(caption);
    }

    function totalFeeds() 
        external view
        returns (uint256)
    {
        return surrogate.lookupPriceFeeds().length;
    }

    function lastValidQueryId(bytes4)
        external pure
        returns (uint256)
    {
        return 0;
    }

    function lastValidQueryResponse(bytes4)
        external pure
        returns (Witnet.QueryResponse memory)
    {}

    function latestUpdateQueryId(bytes4)
        external pure
        returns (uint256)
    {
        return 0;
    }

    function latestUpdateQueryRequest(bytes4)
        external pure
        returns (Witnet.QueryRequest memory _void)
    {}

    function lookupWitnetBytecode(bytes4 feedId)
        external view
        returns (bytes memory)
    {
        IWitPriceFeeds.PriceFeedInfo memory _info = surrogate.lookupPriceFeed(IWitPriceFeedsTypes.ID4.wrap(feedId));
        if (_info.oracle.class == IWitPriceFeedsTypes.Oracles.Witnet) {
            Witnet.RadonHash _radHash = Witnet.RadonHash.wrap(_info.oracle.sources);
            return registry.lookupRadonRequestBytecode(_radHash);
        } else {
            return new bytes(0);
        }
    }

    function lookupWitnetRadHash(bytes4 feedId)
        external view
        returns (bytes32 _void)
    {
        IWitPriceFeeds.PriceFeedInfo memory _info = surrogate.lookupPriceFeed(IWitPriceFeedsTypes.ID4.wrap(feedId));
        if (_info.oracle.class == IWitPriceFeedsTypes.Oracles.Witnet) {
            return _info.oracle.sources;
        } else {
            return bytes32(0);
        }
    }

    function lookupWitnetRetrievals(bytes4 feedId)
        external view
        returns (Witnet.RadonRetrieval[] memory _void)
    {
        IWitPriceFeeds.PriceFeedInfo memory _info = surrogate.lookupPriceFeed(IWitPriceFeedsTypes.ID4.wrap(feedId));
        if (_info.oracle.class == IWitPriceFeedsTypes.Oracles.Witnet) {
            Witnet.RadonHash _radHash = Witnet.RadonHash.wrap(_info.oracle.sources);
            return registry.lookupRadonRequestRetrievals(_radHash);
        } else {
            return new Witnet.RadonRetrieval[](0);
        }
    }

    function requestUpdate(bytes4)
        external payable
        returns (uint256)
    {
        _revertBypass();
    }


    /// ===============================================================================================================
    /// --- IWitFeedsLegacy -------------------------------------------------------------------------------------------
    
    function defaultRadonSLA() 
        external pure
        returns (IWitPriceFeedsLegacy.RadonSLAv1 memory)
    {
        return IWitPriceFeedsLegacy.RadonSLAv1({
            numWitnesses: 5, 
            minConsensusPercentage: 51, 
            minerCommitRevealFee: 2 * 1e6, // 0.002 WIT
            witnessCollateral: 1 * 1e9,    // 1.0   WIT
            witnessReward: 1 * 1e7         // 0.01  WIT
        });
    }

    function latestUpdateResponse(bytes4) 
        external view 
        returns (Witnet.QueryResponse memory)
    {
        _revertBypass();
    }

    function latestUpdateResponseStatus(bytes4)
        external view
        returns (IWitOracleLegacy.QueryResponseStatus)
    {
        _revertBypass();
    }

    function latestUpdateResultError(bytes4)
        external view 
        returns (IWitOracleLegacy.ResultError memory)
    {
        _revertBypass();
    }
    
    function requestUpdate(bytes4, IWitPriceFeedsLegacy.RadonSLAv2 calldata)
        external payable
        returns (uint256)
    {
        _revertBypass();
    }

    function witnet()
        external view 
        returns (address)
    {
        return IWitOracleAppliance(address(surrogate)).witOracle();
    }

    function witOracle()
        external view
        returns (address)
    {
        return IWitOracleAppliance(address(surrogate)).witOracle();
    }


    // ================================================================================================================
    // --- Implements 'IWitPriceFeedsLegacyAdmin' -----------------------------------------------------------------------------

    function owner()
        virtual override
        public view 
        returns (address)
    {
        return Ownable.owner();
    }
    
    function acceptOwnership()
        virtual override 
        public
    {
        Ownable2Step.acceptOwnership();
    }

    function baseFeeOverheadPercentage() external view returns (uint16) {
        _revertBypass();
    }


    function pendingOwner() 
        virtual override 
        public view
        returns (address)
    {
        return Ownable2Step.pendingOwner();
    }
    
    function transferOwnership(address _newOwner)
        virtual override 
        public 
        onlyOwner
    {
        Ownable.transferOwnership(_newOwner);
    }

    function deleteFeed(string calldata) external view {
        _revertBypass();
    }

    function deleteFeeds() external view {
        _revertBypass();
    }

    function settleBaseFeeOverheadPercentage(uint16) external view {
        _revertBypass();
    }

    function settleDefaultRadonSLA(IWitPriceFeedsLegacy.RadonSLAv2 calldata) external view {
        _revertBypass();
    }
    
    function settleFeedRequest(string calldata, bytes32) external view {
        _revertBypass();
    }

    function settleFeedRequest(string calldata, IWitOracleRequest) external view {
        _revertBypass();
    }

    function settleFeedRequest(string calldata, IWitOracleRequestTemplate, string[][] calldata) external view {
        _revertBypass();
    }

    function settleFeedSolver(string calldata, address, string[] calldata) external view {
        _revertBypass();
    }


    // ================================================================================================================
    // --- Implements 'IWitPriceFeeds' -----------------------------------------------------------------------------

    function lookupDecimals(bytes4 feedId) 
        external view
        returns (uint8)
    {
        int8 _exponent = surrogate.lookupPriceFeedExponent(IWitPriceFeedsTypes.ID4.wrap(feedId));
        _require(_exponent <= 0, "uncompliant exponent");
        return uint8(-_exponent);
    }
    
    function lookupPriceSolver(bytes4 feedId)
        external view
        returns (address _solverAddress, string[] memory _solverDeps)
    {
        IWitPriceFeeds.PriceFeedInfo memory _info = surrogate.lookupPriceFeed(IWitPriceFeedsTypes.ID4.wrap(feedId));
        if (_info.mapper.class != IWitPriceFeedsTypes.Mappers.None) {
            _solverAddress = address(surrogate);
            _solverDeps = _info.mapper.deps;
        }
    }

    function latestPrice(bytes4 feedId)
        public view
        returns (IWitPriceFeedsLegacySolver.Price memory)
    {
        IWitPriceFeedsTypes.ID4 _v3Id = (
            IWitPriceFeedsTypes.ID4.unwrap(__bypass().v3Ids[feedId]) != bytes4(0) 
                ? __bypass().v3Ids[feedId]
                : IWitPriceFeedsTypes.ID4.wrap(feedId)
        );
        IWitPriceFeeds.Price memory _lastUpdate = surrogate.getPriceUnsafe(_v3Id);
        return IWitPriceFeedsLegacySolver.Price({
            value: _lastUpdate.price,
            timestamp: _lastUpdate.timestamp,
            drTxHash: _lastUpdate.trail,
            latestStatus: IWitPriceFeedsLegacySolver.LatestUpdateStatus.Ready
        });
    }

    function latestPrices(bytes4[] calldata feedIds)
        external view
        returns (IWitPriceFeedsLegacySolver.Price[] memory _prices)
    {
        _prices = new IWitPriceFeedsLegacySolver.Price[](feedIds.length);
        for (uint _ix = 0; _ix < feedIds.length; _ix ++) {
            _prices[_ix] = latestPrice(feedIds[_ix]);
        }
    }


    // ================================================================================================================
    // --- Implements 'IERC2362' --------------------------------------------------------------------------------------
    
    function valueFor(bytes32 feedId)
        external view
        returns (int256, uint256, uint256)
    {
        bytes4 _v2Id = bytes4(feedId);
        IWitPriceFeedsTypes.ID4 _v3Id = (
            IWitPriceFeedsTypes.ID4.unwrap(__bypass().v3Ids[_v2Id]) != bytes4(0) 
                ? __bypass().v3Ids[_v2Id]
                : IWitPriceFeedsTypes.ID4.wrap(_v2Id)
        );
        IWitPriceFeeds.Price memory _lastUpdate = surrogate.getPriceUnsafe(_v3Id);
        uint256 _timestamp = uint(Witnet.Timestamp.unwrap(_lastUpdate.timestamp));
        return (
            int(int64(_lastUpdate.price)),
            _timestamp,
            _timestamp == 0 ? 404 : 200
        );
    }


    // ================================================================================================================
    // --- Internal methods -------------------------------------------------------------------------------------------

    function _require(bool _condition, string memory _reason) internal pure {
        if (_condition) {
            _revert(_reason);
        }
    }

    function _revert(string memory _reason) internal pure {
        revert(string(abi.encodePacked(
            class(),
            ": ",
            _reason
        )));
    }

    function _revertBypass() internal view {
        _revert(
            string(
                abi.encodePacked(
                    "bypassed to ", 
                    IWitOracleAppliance(address(surrogate)).class()
                )
            )
        );
    }

    bytes32 private constant _BYPASS_V2_V3_STORAGE_SLOT =    
        /* keccak256("io.witnet.feeds.bypass") & ~bytes32(uint256(0xff) */
        0xc5354469a5d32189a18f5e79f9508d828fa089087c317bc89792b1c8dba53900;

    function __bypass() internal pure returns (BypassV2V3 storage _ptr) {
        assembly {
            _ptr.slot := _BYPASS_V2_V3_STORAGE_SLOT       
        }
    }

    function __legacy() internal pure returns (WitPriceFeedsLegacyDataLib.Storage storage _ptr) {
        return WitPriceFeedsLegacyDataLib.data();
    }

}
