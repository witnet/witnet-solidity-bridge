// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleRadonRequestTemplateFactory {

    /// @notice Build a new Radon Request by replacing the `templateArgs` into the factory's
    /// data sources, and the factory's aggregate and tally Radon Reducers.
    /// The returned identifier will be accepted as a valid RAD hash on the witOracle() contract from now on. 
    /// @dev Reverts if the ranks of passed array don't fulfill the actual number of required parameters.
    function buildRadonRequest(string[][] calldata templateArgs) external returns (Witnet.RadonHash);

    /// @notice Returns an array containing the number of arguments expected for each data source.
    function getArgsCount() external view returns (uint8[] memory);

    /// @notice Returns the Radon Reducer applied upon tally of values revealed by witnessing nodes in Witnet.
    function getCrowdAttestationTally() external view returns (Witnet.RadonReducer memory);

    /// @notice Returns the expected data type upon sucessfull resolution of Radon Request built out of this factory.
    function getDataResultType() external view returns (Witnet.RadonDataTypes); 

    /// @notice Returns the underlying Data Sources used by this factory to build new Radon Requests.
    function getDataSources() external view returns (Witnet.DataSource[] memory);    

    /// @notice Returns the Radon Reducer applied to data collected from each data source upon each query resolution. 
    function getDataSourcesAggregator() external view returns (Witnet.RadonReducer memory);


    /// @notice The Wit/Oracle core address where the Radon Requests built out of this factory will be bound to. 
    function witOracle() external view returns (address);
}
