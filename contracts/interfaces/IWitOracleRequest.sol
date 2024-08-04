// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleRequest {

    /// Returns the Witnet-compliant RAD bytecode for the data request (i.e. Radon Request) 
    /// contained within this WitOracleRequest.
    function bytecode() external view returns (bytes memory);

    /// Returns the Witnet-compliant RAD hash of the data request (i.e. Radon Request) 
    /// contained within this WitOracleRequest. 
    function radHash() external view returns (bytes32);

    /// Returns the filters and reducing functions to be applied by witnessing nodes 
    /// on the Witnet blockchain both at the:
    /// - Aggregate stage: when aggregating data extracted from the public 
    ///                    data sources (i.e. Radon Retrievals).
    /// - Tally stage: when aggregating values revealed by witnesses.
    function getRadonReducers() external view returns (
            Witnet.RadonReducer memory aggregateStage,
            Witnet.RadonReducer memory tallyStage
        );

    
    /// Returns metadata concerning the data source specified by the given index.
    function getRadonRetrievalByIndex(uint256) external view returns (Witnet.RadonRetrieval memory);

    /// Returns the array of one or more data sources (i.e. Radon Retrievals) 
    /// that compose this WitOracleRequest.
    function getRadonRetrievals() external view returns (Witnet.RadonRetrieval[] memory);

    /// Returns the expected data type produced by successful resolutions of the 
    /// Witnet-compliant data request contained within this WitOracleRequest.
    function getResultDataType() external view returns (Witnet.RadonDataTypes);

    /// If built out of an upgradable factory, or template, returns the SemVer tag of 
    /// the actual implementation version at the time when this WitOracleRequest got built.
    function version() external view returns (string memory);
}
