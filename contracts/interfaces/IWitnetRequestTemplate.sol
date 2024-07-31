// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitnetRequestTemplate {
    /// Build a WitnetRequest instance that will provide the bytecode and RAD 
    /// hash of some Witnet-compliant Radon Request, provably made out of the 
    /// data sources, aggregate and tally Radon Reducers that compose this WitnetRequestTemplate.
    /// Produced addresses are counter-factual to the given values.
    /// Reverts if:
    /// - the ranks of passed array don't match either the number of this template's 
    ///   data sources, or the number of required parameters by each one of those.
    function buildWitnetRequest (string[][] calldata args) external returns (address);

    /// Returns an array of integers telling the number of parameters required 
    /// by every single data source (i.e. Radon Retrievals) that compose this 
    /// WitnetRequestTemplate. The length of the returned array tells the number 
    /// of data sources that compose this instance.
    function getArgsCount() external view returns (uint256[] memory);

    /// Returns the expected data type produced by successful resolutions of 
    /// any WitnetRequest that gets built out of this WitnetRequestTemplate.
    function getResultDataType() external view returns (Witnet.RadonDataTypes); 

    /// Returns the filters and reducing function to be applied by witnessing 
    /// nodes on the Witnet blockchain when aggregating data extracted from 
    /// the public data sources (i.e. Radon Retrievals) of the data requests 
    /// that get eventually built out of this WitnetRequestTemplate.
    function getAggregateReducer() external view returns (Witnet.RadonReducer memory);

    /// Returns metadata concerning the data source specified by the given index. 
    function getRetrievalByIndex(uint256) external view returns (Witnet.RadonRetrieval memory);

    /// Returns the array of one or more parameterized data sources that compose 
    /// this WitnetRequestTemplate.
    function getRetrievals() external view returns (Witnet.RadonRetrieval[] memory);

    /// Returns the slashing filters and reducing function to be applied to the 
    /// values revealed by the witnessing nodes on the Witnet blockchain that 
    /// contribute to solve data requests built out of this WitnetRequestTemplate.
    function getTallyReducer() external view returns (Witnet.RadonReducer memory);

    /// Verifies into the bounded WitnetOracle's registry the actual bytecode 
    /// and RAD hash of the Witnet-compliant Radon Request that gets provably 
    /// made out of the data sources, aggregate and tally Radon Reducers that 
    /// compose this WitnetRequestTemplate. While no WitnetRequest instance is 
    /// actually constructed, the returned value will be accepted as a valid
    /// RAD hash on the witnet() contract from now on. 
    /// Reverts if:
    /// - the ranks of passed array don't match either the number of this 
    ///   template's data sources, or the number of required parameters by 
    ///   each one of those.
    /// @dev This method requires less gas than buildWitnetRequest(string[][]), and 
    /// it's usually preferred when parameterized data requests made out of this 
    /// template are intended to be used just once in lifetime.    
    function verifyWitnetRequest(string[][] calldata args) external returns (bytes32);

    /// If built out of an upgradable factory, returns the SemVer tag of the 
    /// factory implementation at the time when this WitnetRequestTemplate got built.
    function version() external view returns (string memory);
}
