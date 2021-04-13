// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./WitnetRequestBoardInterface.sol";
import "./Request.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @title Witnet Requests Board mocked
 * @notice Contract to bridge requests to Witnet for testing purposes.
 * @dev This contract enables posting requests that Witnet bridges will insert into the Witnet network.
 * The result of the requests will be posted back to this contract by the bridge nodes too.
 * @author Witnet Foundation
 */
contract WitnetRequestBoard is WitnetRequestBoardInterface {
    // Result reporting is subject to increases due to number of merkle tree levels
    // The following value corresponds to 9 merkle tree levels
    uint256 public constant MAX_REPORT_RESULT_GAS = 102496;

    struct DataRequest {
        address requestAddress;
        address requestor;
        uint256 drOutputHash;
        uint256 tallyReward;
        uint256 gasPrice;
        bytes result;
        uint256 drHash;
    }

    // Owner of the Witnet Request Board
    address public witnet;

    // List of addresses authorized to report data request
    address[] public committee;

    // Witnet Requests within the board
    DataRequest[] public requests;

    // Event emitted when a new DR is posted
    event PostedRequest(address indexed _from, uint256 _id);

    // Event emitted when a result proof is posted
    event PostedResult(address indexed _from, uint256 _id);

    // Only the commitee defined when deploying the contract should be able to push blocks
    modifier isAuthorized() {
        bool senderAuthorized = false;
        for (uint256 i; i < committee.length; i++) {
            if (committee[i] == msg.sender) {
                senderAuthorized = true;
            }
        }
        require(senderAuthorized == true, "Sender not authorized");
        _; // Otherwise, it continues.
    }

    // Ensures the reward is not greater than the value
    modifier payingRewards(uint256 _value, uint256 _rewards) {
        require(
            _value >= _rewards,
            "Transaction value needs to be equal or greater than rewards"
        );
        _;
    }

    // Ensures the result has not been reported yet
    modifier resultNotIncluded(uint256 _id) {
        require(requests[_id].result.length == 0, "Result already included");
        _;
    }

    // Ensures the request has not been manipulated
    modifier validDrOutputHash(uint256 _id) {
        require(
            requests[_id].drOutputHash ==
                uint256(
                    sha256(Request(requests[_id].requestAddress).bytecode())
                ),
            "The dr has been manipulated and the bytecode has changed"
        );
        _;
    }

    // Ensures the request id exists
    modifier validId(uint256 _id) {
        require(requests.length > _id, "Id not found");
        _;
    }

    /// @notice Initilizes a centralized Witnet Request Board with an authorized committee.
    /// @param _committee list of authorized addresses.
    constructor(address[] memory _committee) public {
        witnet = msg.sender;
        committee = _committee;
        // Insert an empty request so as to initialize the requests array with length > 0
        DataRequest memory request;
        requests.push(request);
    }

    /// @dev Posts a data request into the WRB in expectation that it will be relayed and resolved in Witnet with a total reward that equals to msg.value.
    /// @param _requestAddress The request contract address which includes the request bytecode.
    /// @param _tallyReward The amount of value that will be detracted from the transaction value and reserved for rewarding the reporting of the final result (aka tally) of the data request.
    /// @return The unique identifier of the data request.
    function postDataRequest(
        address _requestAddress,
        uint256,
        uint256 _tallyReward
    )
        external
        payable
        override
        payingRewards(msg.value, _tallyReward)
        returns (uint256)
    {
        // Checks the tally reward is covering gas cost
        uint256 minResultReward =
            SafeMath.mul(tx.gasprice, MAX_REPORT_RESULT_GAS);
        require(
            _tallyReward >= minResultReward,
            "Result reward should cover gas expenses. Check the estimateGasCost method."
        );

        uint256 _id = requests.length;

        DataRequest memory request;
        request.requestAddress = _requestAddress;
        request.requestor = msg.sender;
        request.tallyReward = _tallyReward;
        Request requestContract = Request(request.requestAddress);
        uint256 _drOutputHash = uint256(sha256(requestContract.bytecode()));
        request.drOutputHash = _drOutputHash;
        request.gasPrice = tx.gasprice;
        // Push the new request into the contract state
        requests.push(request);

        // Let observers know that a new request has been posted
        emit PostedRequest(msg.sender, _id);

        return _id;
    }

    /// @dev Increments the rewards of a data request by adding more value to it. The new request reward will be increased by msg.value minus the difference between the former tally reward and the new tally reward.
    /// @param _id The unique identifier of the data request.
    /// @param _tallyReward The amount to be added to the tally reward.
    function upgradeDataRequest(
        uint256 _id,
        uint256,
        uint256 _tallyReward
    )
        external
        payable
        override
        payingRewards(msg.value, _tallyReward)
        resultNotIncluded(_id)
    {
        // If gas price is increased, then check if new rewards cover gas costs
        if (tx.gasprice > requests[_id].gasPrice) {
            // Checks the tally reward is covering gas cost
            uint256 minResultReward =
                SafeMath.mul(tx.gasprice, MAX_REPORT_RESULT_GAS);
            require(
                _tallyReward >= minResultReward,
                "Result reward should cover gas expenses. Check the estimateGasCost method."
            );
            requests[_id].gasPrice = tx.gasprice;
        }

        // Update data request reward
        requests[_id].tallyReward = SafeMath.add(
            requests[_id].tallyReward,
            _tallyReward
        );
    }

    /// @dev Reports the result of a data request in Witnet.
    /// @param _id The unique identifier of the data request.
    /// @param _drHash The unique hash of the request.
    /// @param _result The result itself as bytes.
    function reportResult(
        uint256 _id,
        uint256 _drHash,
        bytes calldata _result
    ) external isAuthorized() validId(_id) resultNotIncluded(_id) {
        // Ensures the result byes do not have zero length
        // This would not be a valid encoding with CBOR and could trigger a reentrancy attack
        require(_result.length != 0, "Result has zero length");

        requests[_id].drHash = _drHash;
        requests[_id].result = _result;
        msg.sender.transfer(requests[_id].tallyReward);

        emit PostedResult(msg.sender, _id);
    }

    /// @dev Retrieves the bytes of the serialization of one data request from the WRB.
    /// @param _id The unique identifier of the data request.
    /// @return The result of the data request as bytes.
    function readDataRequest(uint256 _id)
        external
        view
        validId(_id)
        validDrOutputHash(_id)
        returns (bytes memory)
    {
        Request requestContract = Request(requests[_id].requestAddress);
        return requestContract.bytecode();
    }

    /// @dev Retrieves the result (if already available) of one data request from the WRB.
    /// @param _id The unique identifier of the data request.
    /// @return The result of the DR.
    function readResult(uint256 _id)
        external
        view
        override
        validId(_id)
        returns (bytes memory)
    {
        return requests[_id].result;
    }

    /// @dev Retrieves the gas price set for a specific DR ID.
    /// @param _id The unique identifier of the data request.
    /// @return The gas price set by the request creator.
    function readGasPrice(uint256 _id)
        external
        view
        validId(_id)
        returns (uint256)
    {
        return requests[_id].gasPrice;
    }

    /// @dev Retrieves hash of the data request transaction in Witnet.
    /// @param _id The unique identifier of the data request.
    /// @return The hash of the DataRequest transaction in Witnet.
    function readDrHash(uint256 _id)
        external
        view
        override
        validId(_id)
        returns (uint256)
    {
        return requests[_id].drHash;
    }

    /// @dev Returns the number of data requests in the WRB.
    /// @return the number of data requests in the WRB.
    function requestsCount() external view returns (uint256) {
        return requests.length;
    }

    /// @dev Verifies if the contract is upgradable.
    /// @return true if the contract upgradable.
    function isUpgradable(address _address)
        external
        view
        override
        returns (bool)
    {
        if (_address == witnet) {
            return true;
        }
        return false;
    }

    /// @dev Estimate the amount of reward we need to insert for a given gas price.
    /// @param _gasPrice The gas price for which we need to calculate the rewards.
    /// @return The rewards to be included for the given gas price as inclusionReward, resultReward, blockReward.
    function estimateGasCost(uint256 _gasPrice)
        public
        view
        override
        returns (uint256, uint256, uint256)
    {
        return ((0, SafeMath.mul(_gasPrice, MAX_REPORT_RESULT_GAS), 0));
    }
}
