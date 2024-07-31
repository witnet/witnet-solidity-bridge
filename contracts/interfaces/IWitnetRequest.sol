// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "./IWitnetRequestTemplate.sol";

interface IWitnetRequest {

    /// Returns the Witnet-compliant RAD bytecode for the data request (i.e. Radon Request) 
    /// contained within this WitnetRequest.
    function bytecode() external view returns (bytes memory);

    /// Returns the Witnet-compliant RAD hash of the data request (i.e. Radon Request) 
    /// contained within this WitnetRequest. 
    function radHash() external view returns (bytes32);
    
    /// If built out of a WitnetRequestTemplate, returns the array or string values 
    /// passed as parameters when this WitnetRequest got built.
    function getArgs() external view returns (string[][] memory);

    /// Returns the expected data type produced by successful resolutions of the 
    /// Witnet-compliant data request contained within this WitnetRequest.
    function getResultDataType() external view returns (Witnet.RadonDataTypes);

    /// Returns the filters and reducing function to be applied by witnessing nodes 
    /// on the Witnet blockchain when aggregating data extracted from the public 
    /// data sources (i.e. Radon Retrievals) as specified within this WitnetRequest.
    function getAggregateReducer() external view returns (Witnet.RadonReducer memory);
    
    /// Returns metadata concerning the data source specified by the given index.
    function getRetrievalByIndex(uint256) external view returns (Witnet.RadonRetrieval memory);

    /// Returns the array of one or more data sources (i.e. Radon Retrievals) 
    /// that compose this WitnetRequest.
    function getRetrievals() external view returns (Witnet.RadonRetrieval[] memory);

    /// Returns the slashing filters and reducing function to be applied to the
    /// values revealed by the witnessing nodes on the Witnet blockchain that 
    /// contribute to solve the data request as specified within this WitnetRequest.
    function getTallyReducer() external view returns (Witnet.RadonReducer memory);

    /// If built out of a template, returns the address of the WitnetRequestTemplate 
    /// from which this WitnetRequest instance got built.
    function template() external view returns (IWitnetRequestTemplate);

    /// If built out of an upgradable factory, or template, returns the SemVer tag of 
    /// the actual implementation version at the time when this WitnetRequest got built.
    function version() external view returns (string memory);
}
