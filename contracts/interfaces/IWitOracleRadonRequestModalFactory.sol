// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleRadonRequestModalFactory {

    /// @notice Build a new Radon Request by repeating the factory's data source request
    /// as many times as the number of provided `modalUrls`, replacing on each
    /// resulting data source the specified `modalArgs` parameters, and the factory's 
    /// crowd-attestation Radon Reducer.
    /// The returned identifier will be accepted as a valid RAD hash on the witOracle() contract from now on. 
    /// @dev Reverts if the ranks of passed array don't fulfill the actual number of required parameters.
    function buildRadonRequest(
            string[] calldata modalArgs, 
            string[] calldata modalUrls
        ) external returns (Witnet.RadonHash);

    /// @notice Returns the Radon Reducer applied upon tally of values revealed by witnessing nodes in Witnet.
    function getCrowdAttestationTally() external view returns (Witnet.RadonReducer memory);

    /// @notice Returns the expected data type upon sucessfull resolution of Radon Request built out of this factory.
    function getDataResultType() external view returns (Witnet.RadonDataTypes); 

    /// @notice Returns the number of expected parameters of the underlying Data Source Request.
    function getDataSourceArgsCount(string calldata url) external view returns (uint8);

    /// @notice Returns the underlying Data Source Request used by this factory to build new Radon Requests.
    function getDataSourceRequest() external view returns (Witnet.DataSourceRequest memory);
    
    /// @notice The Wit/Oracle core address where the Radon Requests built out of this factory will be bound to. 
    function witOracle() external view returns (address);
}
