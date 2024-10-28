// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IWitOracleLegacy {

    event WitnetQuery(uint256 id, uint256 evmReward, RadonSLA witnetSLA);

    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Underestimates if the size of returned data is greater than `resultMaxSize`. 
    /// @param gasPrice Expected gas price to pay upon posting the data request.
    /// @param resultMaxSize Maximum expected size of returned data (in bytes).  
    function estimateBaseFee(uint256 gasPrice, uint16 resultMaxSize) external view returns (uint256);
    
    /// @notice Estimate the minimum reward required for posting a data request.
    /// @dev Fails if the RAD hash was not previously verified on the WitOracleRadonRegistry registry.
    /// @param gasPrice Expected gas price to pay upon posting the data request.
    /// @param radHash The RAD hash of the data request to be solved by Witnet.
    function estimateBaseFee(uint256 gasPrice, bytes32 radHash) external view returns (uint256);

    struct RadonSLA {
        uint8 witCommitteeCapacity;
        uint64 witCommitteeUnitaryReward;
    }
    function postRequest(bytes32, RadonSLA calldata) external payable returns (uint256);
    function postRequestWithCallback(bytes32, RadonSLA calldata, uint24) external payable returns (uint256);
    function postRequestWithCallback(bytes calldata, RadonSLA calldata, uint24) external payable returns (uint256);
}
