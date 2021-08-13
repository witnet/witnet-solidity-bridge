// SPDX-License-Identifier: MIT

/* solhint-disable var-name-mixedcase */

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

// Inherits from:
import "../WitnetBoardUpgradableBase.sol";
import "../../data/WitnetBoardDataACLs.sol";

// Uses:
import "../../interfaces/IERC20.sol";

/// @title Witnet Requests Board V03 - OVM.
/// @notice Contract to bridge requests to Witnet Decenetralized Oracle Network.
/// @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
/// The result of the requests will be posted back to this contract by the bridge nodes too.
/// @author The Witnet Foundation
contract WitnetRequestBoardV03OVM
    is
        WitnetBoardUpgradableBase,
        WitnetBoardDataACLs
{
    /// OVM_ETH ERC20-compliant address.
    IERC20 public immutable OVM_ETH;

    uint256 internal lastBalance;

    uint256 internal constant _ESTIMATED_REPORT_RESULT_GAS = 102496;
    uint256 internal immutable _OVM_GAS_PRICE;        
    
    constructor(
            bool _upgradable,
            bytes32 _versionTag,
            uint256 _layer2GasPrice,
            IERC20 _oETH
        )
        WitnetBoardUpgradableBase(_upgradable, _versionTag)
    {
        _OVM_GAS_PRICE = _layer2GasPrice;        
        require(address(_oETH) != address(0), "WitnetRequestBoardV03OVM: null currency");
        OVM_ETH = _oETH;        
    }

    modifier ovmPayable {
        _;
        lastBalance = _balanceOf(address(this));
    }

    /// Calculates `msg.value` equivalent OVM_ETH value. 
    /// @dev Based on `lastBalance` value.
    function _msgValue() internal view returns (uint256) {
        uint256 _newBalance = _balanceOf(address(this));
        assert(_newBalance >= lastBalance);
        return _newBalance - lastBalance;
    }

    /// Gets OVM_ETH balance of given address.
    function _balanceOf(address _from) internal view returns (uint256) {
        return OVM_ETH.balanceOf(_from);
    }

    /// Transfers oETHs to given address.
    /// @dev Updates `lastBalance` value.
    /// @param _to OVM_ETH recipient account.
    /// @param _amount Amount of oETHs to transfer.
    function _safeTransferTo(address payable _to, uint256 _amount) internal {
        uint256 _balance = _balanceOf(address(this));
        require(_amount <= _balance, "WitnetRequestBoardV03OVM: insufficient funds");
        lastBalance = _balance - _amount;
        OVM_ETH.transfer(_to, _amount);
    }

    // ================================================================================================================
    // --- Overrides 'Upgradable' -------------------------------------------------------------------------------------

    /// Initialize storage-context when invoked as delegatecall. 
    /// @dev Should fail when trying to initialize same instance more than once.
    function initialize(bytes memory _initData) virtual external override {
        // Initialize owner:
        address _owner = _state().owner;
        if (_owner == address(0)) {
            // set owner if none set yet
            _owner = msg.sender;
            _state().owner = _owner;
        } else {
            // only owner can initialize:
            require(msg.sender == _owner, "WitnetRequestBoard: only owner");
        }        

        // Check initialize-once condition:
        if (_state().base != address(0)) {
            // current implementation cannot be initialized more than once:
            require(_state().base != base(), "WitnetRequestBoard: already initialized");
        }        
        _state().base = base();        

        emit Initialized(msg.sender, base(), codehash(), version());

        // Do actual base initialization:
        lastBalance = _balanceOf(address(this));
        setReporters(abi.decode(_initData, (address[])));
    }

    /// Tells whether provided address could eventually upgrade the contract.
    function isUpgradableFrom(address _from) external view override returns (bool) {
        address _owner = _state().owner;
        return (
            // false if the WRB is intrinsically not upgradable
            isUpgradable() && (                
                _owner == address(0) ||
                _owner == _from
            )
        );
    }


    // ================================================================================================================
    // --- Utility functions not declared within an interface ---------------------------------------------------------

    /// Retrieves the whole DR post record from the WRB.
    /// @param _id The unique identifier of a previously posted data request.
    /// @return The DR record. Fails if DR current bytecode differs from the one it had when posted.
    function readDr(uint256 _id)
        external view
        virtual
        wasPosted(_id)
        returns (WitnetData.Query memory)
    {
        return _checkDr(_id);
    }
    
    /// Retrieves the Radon script bytecode of a previously posted DR. Fails if changed after being posted. 
    /// @param _id The unique identifier of the previously posted DR.
    /// @return _bytecode The Radon script bytecode. Empty if the DR was already solved and destroyed.
    function readDataRequest(uint256 _id)
        external view
        virtual
        wasPosted(_id)
        returns (bytes memory _bytecode)
    {
        WitnetData.Query storage _dr = _getRequestQuery(_id);
        if (_dr.script != address(0)) {
            // if DR's request contract address is not zero,
            // we assume the DR has not been destroyed, so
            // DR's bytecode can still be fetched:
            _bytecode = WitnetRequest(_dr.script).bytecode();
            require(
                WitnetData.computeScriptCodehash(_bytecode) == _dr.codehash,
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
        return _getRequestQuery(_id).gasprice;
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

        WitnetBoardDataRequest storage _record = _state().requests[_id];
        _record.query.txhash = _txhash;
        _record.result = _result;

        emit PostedResult(_id, msg.sender);
        _safeTransferTo(payable(msg.sender), _record.query.reward);
    }
    
    /// @dev Returns the number of posted data requests in the WRB.
    /// @return The number of posted data requests in the WRB.
    function requestsCount() external virtual view returns (uint256) {
        // TODO: either rename this method (e.g. getNextId()) or change bridge node 
        //       as to interpret returned value as actual number of posted data requests 
        //       in the WRB.
        return _state().numRecords + 1;
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
            _acls().isReporter_[_reporter] = true;
        }
    }

    
    // ================================================================================================================
    // --- Implements 'WitnetRequestBoardInterface' -------------------------------------------------------------------

    /// @dev Estimate the minimal amount of reward we need to insert for a given gas price.
    /// @return The minimal reward to be included for the given gas price.
    function estimateGasCost(uint256)
        external view
        virtual override
        returns (uint256)
    {
        // TODO: consider renaming this method as `estimateReward(uint256 _gasPrice)`
        return _OVM_GAS_PRICE * _ESTIMATED_REPORT_RESULT_GAS;
    }

    /// @dev Retrieves result of previously posted DR, and removes it from storage.
    /// @param _id The unique identifier of a previously posted data request.
    /// @return _result The CBOR-encoded result of the DR.
    function destroyResult(uint256 _id)
        external
        virtual override
        returns (bytes memory _result)
    {
        WitnetBoardDataRequest storage _record = _state().requests[_id];
        require(msg.sender == _record.query.requestor, "WitnetRequestBoard: only actual requestor");
        require(_record.query.txhash != 0, "WitnetRequestBoard: not yet solved");
        _result = _record.result;
        delete _state().requests[_id];
        emit DestroyedResult(_id, msg.sender);
    }

    /// @dev Posts a data request into the WRB in expectation that it will be relayed 
    /// @dev and resolved in Witnet with a total reward that equals to msg.value.
    /// @param _requestAddr The Witnet request contract address which provides actual RADON bytecode.
    /// @return _id The unique identifier of the posted DR.
    function postDataRequest(address _requestAddr)
        public payable
        ovmPayable
        virtual override
        returns (uint256 _id)
    {
        uint256 _value = _msgValue();

        require(_requestAddr != address(0), "WitnetRequestBoard: null request");

        // Checks the tally reward is covering gas cost
        uint256 minResultReward = _OVM_GAS_PRICE * _ESTIMATED_REPORT_RESULT_GAS;
        require(_value >= minResultReward, "WitnetRequestBoard: reward too low");

        _id = ++ _state().numRecords;
        WitnetData.Query storage _dr = _getRequestQuery(_id);

        _dr.script = _requestAddr;
        _dr.requestor = msg.sender;
        _dr.codehash = WitnetData.computeScriptCodehash(
            WitnetRequest(_requestAddr).bytecode()
        );
        _dr.gasprice = _OVM_GAS_PRICE;
        _dr.reward = _value;

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
        return _getRequestQuery(_id).txhash;
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
        WitnetBoardDataRequest storage _record = _state().requests[_id];
        require(_record.query.txhash != 0, "WitnetRequestBoard: not yet solved");
        return _record.result;
    }    

    /// @dev Increments the reward of a data request by adding the transaction value to it.
    /// @param _id The unique identifier of a previously posted data request.
    function upgradeDataRequest(uint256 _id)
        external payable
        virtual override        
        wasPosted(_id)
    {
        WitnetData.Query storage _dr = _getRequestQuery(_id);
        require(_dr.txhash == 0, "WitnetRequestBoard: already solved");

        uint256 _newReward = _dr.reward + msg.value;

        // If gas price is increased, then check if new rewards cover gas costs
        if (_OVM_GAS_PRICE > _dr.gasprice) {
            // Checks the reward is covering gas cost
            uint256 _minResultReward = _OVM_GAS_PRICE * _ESTIMATED_REPORT_RESULT_GAS;
            require(
                _newReward >= _minResultReward,
                "WitnetRequestBoard: reward too low"
            );
            _dr.gasprice = _OVM_GAS_PRICE;
        }
        _dr.reward = _newReward;
    }


    // ================================================================================================================
    // --- Private functions ------------------------------------------------------------------------------------------

    function _checkDr(uint256 _id)
        private view returns (WitnetData.Query storage _dr)
    {
        _dr = _getRequestQuery(_id);
        if (_dr.script != address(0)) {
            // if DR's request contract address is not zero,
            // we assume the DR has not been destroyed, so
            // DR's bytecode can still be fetched:
            bytes memory _bytecode = WitnetRequest(_dr.script).bytecode();
            require(
                WitnetData.computeScriptCodehash(_bytecode) == _dr.codehash,
                "WitnetRequestBoard: bytecode changed after posting"
            );
        }        
    }
}
