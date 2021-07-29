// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "../WitnetBoard.sol";
import "../../data/WitnetBoardDataACLs.sol";
import "../../interfaces/WitnetRequestBoardInterface.sol";
import "../../utils/Destructible.sol";
import "../../utils/Upgradable.sol";

/**
 * @title Witnet Requests Board
 * @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
 * The result of the requests will be posted back to this contract by the bridge nodes too.
 * @author Witnet Foundation
 */
contract WitnetRequestBoard
    is 
        Destructible,
        Upgradable, 
        WitnetBoard, 
        WitnetBoardDataACLs
{
    uint256 internal constant __ESTIMATED_REPORT_RESULT_GAS = 102496;
    bytes32 internal immutable __version;

    constructor(bool _isUpgradable, bytes32 _versionTag)
        Upgradable(_isUpgradable)
    {
        __version = _versionTag;
    }


    // ================================================================================================================
    // --- Overrides 'Destructible' -----------------------------------------------------------------------------------

    function destroy() external override onlyOwner {
        selfdestruct(payable(msg.sender));
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

    /// @dev Retrieves named version of current implementation.
    function version() public view override returns (bytes32) {
        return __version;
    }


    // ================================================================================================================
    // --- Utility functions not declared within an interface ---------------------------------------------------------

    /// @dev Gets admin/owner address.
    function owner() external view returns (address) {
        return __data().owner;
    }
        

    /// @dev Retrieves the whole DR post record from the WRB.
    /// @param id The unique identifier of a previously posted data request.
    /// @return The DR record. Fails if DR current bytecode differs from the one it had when posted.
    function readDr(uint256 id)
        external view
        virtual
        wasPosted(id)
        returns (WitnetData.Request memory)
    {
        return __checkDr(id);
    }
    
    /// @dev Retrieves RADON bytecode of a previously posted DR.
    /// @param id The unique identifier of the previously posted DR.
    /// @return _bytecode The RADON bytecode. Fails if changed after being posted. Empty if the DR was solved and destroyed.
    function readDataRequest(uint256 id)
        external view
        virtual
        wasPosted(id)
        returns (bytes memory _bytecode)
    {
        WitnetData.Request storage _dr = __dataRequest(id);
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
    /// @param id The unique identifier of a previously posted DR.
    /// @return The latest gas price set by either the DR requestor, or upgrader.
    function readGasPrice(uint256 id)
        external view
        virtual
        wasPosted(id)
        returns (uint256)
    {
        return __dataRequest(id).gasprice;
    }

    /// @dev Reports the result of a data request solved by Witnet network.
    /// @param id The unique identifier of the data request.
    /// @param txhash Hash of the solving tally transaction in Witnet.
    /// @param result The result itself as bytes.
    function reportResult(
            uint256 id,
            uint256 txhash,
            bytes calldata result
        )
        external
        virtual
        onlyReporters
        notDestroyed(id)
        resultNotYetReported(id)
    {
        require(txhash != 0, "WitnetRequestBoard: Witnet tally tx hash cannot be zero");
        // Ensures the result byes do not have zero length
        // This would not be a valid encoding with CBOR and could trigger a reentrancy attack
        require(result.length != 0, "WitnetRequestBoard: result cannot be empty");

        SWitnetBoardDataRecord storage _record = __data().records[id];
        _record.request.txhash = txhash;
        _record.result = result;

        emit PostedResult(id, msg.sender);
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
    /// @param reporters List of addresses to be added to the active reporters control list.
    function setReporters(address[] memory reporters)
        public
        virtual
        onlyOwner
    {
        for (uint ix = 0; ix < reporters.length; ix ++) {
            address _reporter = reporters[ix];
            __acls().isReporter_[_reporter] = true;
        }
    }

    
    // ================================================================================================================
    // --- Implements 'WitnetRequestBoardInterface' -------------------------------------------------------------------

    /// @dev Estimate the amount of reward we need to insert for a given gas price.
    /// @param gasPrice The gas price for which we need to calculate the rewards.
    /// @return The reward to be included for the given gas price.
    function estimateGasCost(uint256 gasPrice)
        external pure
        virtual override
        returns (uint256)
    {
        return gasPrice * __ESTIMATED_REPORT_RESULT_GAS;
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
    /// @param requestAddr The Witnet request contract address which provides actual RADON bytecode.
    /// @return _id The unique identifier of the posted DR.
    function postDataRequest(address requestAddr)
        public payable
        virtual override
        returns (uint256 _id)
    {
        require(requestAddr != address(0), "WitnetRequestBoard: null request");

        // Checks the tally reward is covering gas cost
        uint256 minResultReward = tx.gasprice * __ESTIMATED_REPORT_RESULT_GAS;
        require(msg.value >= minResultReward, "WitnetRequestBoard: reward too low");

        _id = ++ __data().numRecords;
        WitnetData.Request storage _dr = __dataRequest(_id);

        _dr.addr = requestAddr;
        _dr.requestor = msg.sender;
        _dr.codehash = WitnetData.computeDataRequestCodehash(
            WitnetRequest(requestAddr).bytecode()
        );
        _dr.gasprice = tx.gasprice;
        _dr.reward = msg.value;

        // Let observers know that a new request has been posted
        emit PostedRequest(_id, msg.sender);
    }
    
    /// @dev Retrieves Witnet tx hash of a previously solved DR.
    /// @param id The unique identifier of a previously posted data request.
    /// @return The hash of the DataRequest transaction in Witnet.
    function readDrTxHash(uint256 id)
        external view        
        virtual override
        wasPosted(id)
        returns (uint256)
    {
        return __dataRequest(id).txhash;
    }   
    
    /// @dev Retrieves the result (if already available) of one data request from the WRB.
    /// @param id The unique identifier of the data request.
    /// @return The result of the DR.
    function readResult(uint256 id)
        external view
        virtual override        
        wasPosted(id)
        returns (bytes memory)
    {
        SWitnetBoardDataRecord storage _record = __data().records[id];
        require(_record.request.txhash != 0, "WitnetRequestBoard: not yet solved");
        return _record.result;
    }    

    /// @dev Increments the reward of a data request by adding the transaction value to it.
    /// @param id The unique identifier of a previously posted data request.
    function upgradeDataRequest(uint256 id)
        external payable
        virtual override        
        wasPosted(id)        
    {
        WitnetData.Request storage _dr = __dataRequest(id);
        require(_dr.txhash == 0, "WitnetRequestBoard: already solved");

        uint256 _newReward = _dr.reward + msg.value;

        // If gas price is increased, then check if new rewards cover gas costs
        if (tx.gasprice > _dr.gasprice) {
            // Checks the reward is covering gas cost
            uint256 _minResultReward = tx.gasprice * __ESTIMATED_REPORT_RESULT_GAS;
            require(
                _newReward >= _minResultReward,
                "WitnetRequestBoard: reward too low"
            );
            _dr.gasprice = tx.gasprice;
        }
        _dr.reward = _newReward;
    }


    // ================================================================================================================
    // --- Private functions ------------------------------------------------------------------------------------------

    function __checkDr(uint256 id)
        private view returns (WitnetData.Request storage _dr)
    {
        _dr = __dataRequest(id);
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
