// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../WitnetRequestBoardUpgradableBase.sol";
import "../../data/WitnetBoardDataACLs.sol";

/**
 * @title Witnet Requests Board V03 - Layer 2
 * @notice Contract to bridge requests to Witnet Decenetralized Oracle Network.
 * @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
 * The result of the requests will be posted back to this contract by the bridge nodes too.
 * @author Witnet Foundation
 */
contract WitnetRequestBoardV03L2
    is 
        WitnetRequestBoardUpgradableBase,
        WitnetBoardDataACLs
{
    uint256 internal constant __ESTIMATED_REPORT_RESULT_GAS = 102496;
    uint256 internal immutable __layer2GasPrice;
    
    constructor(
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _layer2GasPrice
        )
        WitnetRequestBoardUpgradableBase(_upgradable, _versionTag)
    {
        __layer2GasPrice = _layer2GasPrice;
    }


    // ================================================================================================================
    // --- Overrides 'Upgradable' -------------------------------------------------------------------------------------

    /// @dev Initialize storage-context when invoked as delegatecall. 
    /// @dev Should fail when trying to initialize same instance more than once.
    function initialize(bytes memory _initData) virtual external override {
        address _owner = __data().owner;
        if (_owner == address(0)) {
            // set owner if none set yet
            _owner = msg.sender;
            __data().owner = _owner;
        } else {
            // only owner can initialize:
            require(msg.sender == _owner, "WitnetRequestBoard: only owner");
        }        

        if (__data().base != address(0)) {
            // current implementation cannot be initialized more than once:
            require(__data().base != base(), "WitnetRequestBoard: already initialized");
        }        
        __data().base = base();

        emit Initialized(msg.sender, base(), codehash(), version());

        // Do actual base initialization:
        setReporters(abi.decode(_initData, (address[])));
    }

    /// @dev Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address from) external view override returns (bool) {
        address _owner = __data().owner;
        return (
            // false if the WRB is intrinsically not upgradable
            isUpgradable() && (                
                _owner == address(0) ||
                _owner == from
            )
        );
    }


    // ================================================================================================================
    // --- Utility functions not declared within an interface ---------------------------------------------------------

    /// @dev Retrieves the whole DR post record from the WRB.
    /// @param _id The unique identifier of a previously posted data request.
    /// @return The DR record. Fails if DR current bytecode differs from the one it had when posted.
    function readDr(uint256 _id)
        external view
        virtual
        wasPosted(_id)
        returns (WitnetData.Request memory)
    {
        return __checkDr(_id);
    }
    
    /// @dev Retrieves RADON bytecode of a previously posted DR.
    /// @param _id The unique identifier of the previously posted DR.
    /// @return _bytecode The RADON bytecode. Fails if changed after being posted. Empty if the DR was solved and destroyed.
    function readDataRequest(uint256 _id)
        external view
        virtual
        wasPosted(_id)
        returns (bytes memory _bytecode)
    {
        WitnetData.Request storage _dr = __dataRequest(_id);
        if (_dr.addr != address(0)) {
            // if DR's request contract address is not zero,
            // we assume the DR has not been destroyed, so
            // DR's bytecode can still be fetched:
            _bytecode = WitnetRequest(_dr.addr).bytecode();
            require(
                WitnetData.computeDataRequestCodehash(_bytecode) == _dr.codehash,
                "WitnetRequestBoard: bytecode changed after posting"
            );
        } 
    }

    /// @dev Retrieves the gas price set for a previously posted DR.
    /// @param _id The unique identifier of a previously posted DR.
    /// @return The latest gas price set by either the DR requestor, or upgrader.
    function readGasPrice(uint256 _id)
        external view
        virtual
        wasPosted(_id)
        returns (uint256)
    {
        return __dataRequest(_id).gasprice;
    }

    /// @dev Reports the result of a data request solved by Witnet network.
    /// @param _id The unique identifier of the data request.
    /// @param _txhash Hash of the solving tally transaction in Witnet.
    /// @param _result The result itself as bytes.
    function reportResult(
            uint256 _id,
            uint256 _txhash,
            bytes calldata _result
        )
        external
        virtual
        onlyReporters
        notDestroyed(_id)
        resultNotYetReported(_id)
    {
        require(_txhash != 0, "WitnetRequestBoard: Witnet tally tx hash cannot be zero");
        // Ensures the result byes do not have zero length
        // This would not be a valid encoding with CBOR and could trigger a reentrancy attack
        require(_result.length != 0, "WitnetRequestBoard: result cannot be empty");

        SWitnetBoardDataRecord storage _record = __data().records[_id];
        _record.request.txhash = _txhash;
        _record.result = _result;

        emit PostedResult(_id, msg.sender);
        payable(msg.sender).transfer(_record.request.reward);
    }
    
    /// @dev Returns the number of posted data requests in the WRB.
    /// @return The number of posted data requests in the WRB.
    function requestsCount() external virtual view returns (uint256) {
        // TODO: either rename this method (e.g. getNextId()) or change bridge node 
        //       as to interpret returned value as actual number of posted data requests 
        //       in the WRB.
        return __data().numRecords + 1;
    }

    /// @dev Adds given addresses to the active reporters control list.
    /// @param _reporters List of addresses to be added to the active reporters control list.
    function setReporters(address[] memory _reporters)
        public
        virtual
        onlyOwner
    {
        for (uint ix = 0; ix < _reporters.length; ix ++) {
            address _reporter = _reporters[ix];
            __acls().isReporter_[_reporter] = true;
        }
    }

    
    // ================================================================================================================
    // --- Implements 'WitnetRequestBoardInterface' -------------------------------------------------------------------

    /// @dev Estimate the minimal amount of reward we need to insert for a given gas price.
    /// @param _gasPrice The gas price for which we need to calculate the rewards.
    /// @return The minimal reward to be included for the given gas price.
    function estimateGasCost(uint256 _gasPrice)
        external pure
        virtual override
        returns (uint256)
    {
        // TODO: consider renaming this method as `estimateMinimalReward(uint256 _gasPrice)`
        return _gasPrice * __ESTIMATED_REPORT_RESULT_GAS;
    }

    /// @dev Retrieves result of previously posted DR, and removes it from storage.
    /// @param _id The unique identifier of a previously posted data request.
    /// @return _result The CBOR-encoded result of the DR.
    function destroyResult(uint256 _id)
        external
        virtual override
        returns (bytes memory _result)
    {
        SWitnetBoardDataRecord storage _record = __data().records[_id];
        require(msg.sender == _record.request.requestor, "WitnetRequestBoard: only actual requestor");
        require(_record.request.txhash != 0, "WitnetRequestBoard: not yet solved");
        _result = _record.result;
        delete __data().records[_id];
        emit DestroyedResult(_id, msg.sender);
    }

    /// @dev Posts a data request into the WRB in expectation that it will be relayed 
    /// @dev and resolved in Witnet with a total reward that equals to msg.value.
    /// @param _requestAddr The Witnet request contract address which provides actual RADON bytecode.
    /// @return _id The unique identifier of the posted DR.
    function postDataRequest(address _requestAddr)
        public payable
        virtual override
        returns (uint256 _id)
    {
        require(_requestAddr != address(0), "WitnetRequestBoard: null request");

        // Checks the tally reward is covering gas cost
        uint256 minResultReward = __layer2GasPrice * __ESTIMATED_REPORT_RESULT_GAS;
        require(msg.value >= minResultReward, "WitnetRequestBoard: reward too low");

        _id = ++ __data().numRecords;
        WitnetData.Request storage _dr = __dataRequest(_id);

        _dr.addr = _requestAddr;
        _dr.requestor = msg.sender;
        _dr.codehash = WitnetData.computeDataRequestCodehash(
            WitnetRequest(_requestAddr).bytecode()
        );
        _dr.gasprice = __layer2GasPrice;
        _dr.reward = msg.value;

        // Let observers know that a new request has been posted
        emit PostedRequest(_id, msg.sender);
    }
    
    /// @dev Retrieves Witnet tx hash of a previously solved DR.
    /// @param _id The unique identifier of a previously posted data request.
    /// @return The hash of the DataRequest transaction in Witnet.
    function readDrTxHash(uint256 _id)
        external view        
        virtual override
        wasPosted(_id)
        returns (uint256)
    {
        return __dataRequest(_id).txhash;
    }
    
    /// @dev Retrieves the result (if already available) of one data request from the WRB.
    /// @param _id The unique identifier of the data request.
    /// @return The result of the DR.
    function readResult(uint256 _id)
        external view
        virtual override        
        wasPosted(_id)
        returns (bytes memory)
    {
        SWitnetBoardDataRecord storage _record = __data().records[_id];
        require(_record.request.txhash != 0, "WitnetRequestBoard: not yet solved");
        return _record.result;
    }    

    /// @dev Increments the reward of a data request by adding the transaction value to it.
    /// @param _id The unique identifier of a previously posted data request.
    function upgradeDataRequest(uint256 _id)
        external payable
        virtual override        
        wasPosted(_id)
    {
        WitnetData.Request storage _dr = __dataRequest(_id);
        require(_dr.txhash == 0, "WitnetRequestBoard: already solved");

        uint256 _newReward = _dr.reward + msg.value;

        // If gas price is increased, then check if new rewards cover gas costs
        if (__layer2GasPrice > _dr.gasprice) {
            // Checks the reward is covering gas cost
            uint256 _minResultReward = __layer2GasPrice * __ESTIMATED_REPORT_RESULT_GAS;
            require(
                _newReward >= _minResultReward,
                "WitnetRequestBoard: reward too low"
            );
            _dr.gasprice = __layer2GasPrice;
        }
        _dr.reward = _newReward;
    }


    // ================================================================================================================
    // --- Private functions ------------------------------------------------------------------------------------------

    function __checkDr(uint256 _id)
        private view returns (WitnetData.Request storage _dr)
    {
        _dr = __dataRequest(_id);
        if (_dr.addr != address(0)) {
            // if DR's request contract address is not zero,
            // we assume the DR has not been destroyed, so
            // DR's bytecode can still be fetched:
            bytes memory _bytecode = WitnetRequest(_dr.addr).bytecode();
            require(
                WitnetData.computeDataRequestCodehash(_bytecode) == _dr.codehash,
                "WitnetRequestBoard: bytecode changed after posting"
            );
        }        
    }
}
