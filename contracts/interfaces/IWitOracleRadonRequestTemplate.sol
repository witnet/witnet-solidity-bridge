// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../libs/Witnet.sol";

interface IWitOracleRadonRequestTemplate {

    function getCrowdAttestationTally() external view returns (Witnet.RadonReducer memory);
    function getDataResultType() external view returns (Witnet.RadonDataTypes); 
    function getDataSources() external view returns (Witnet.RadonRetrieval[] memory);
    function getDataSourcesAggregator() external view returns (Witnet.RadonReducer memory);
    function getDataSourcesArgsCount() external view returns (uint8[] memory);
    
    /// Verifies into the bounded WitOracle's registry the actual bytecode 
    /// and RAD hash of the Witnet-compliant Radon Request that gets provably 
    /// made out of the data sources, aggregate and tally Radon Reducers that 
    /// compose this WitOracleRequestTemplate. While no WitOracleRequest instance is 
    /// actually constructed, the returned value will be accepted as a valid
    /// RAD hash on the witOracle() contract from now on. 
    /// Reverts if:
    /// - the ranks of passed array don't match either the number of this 
    ///   template's data sources, or the number of required parameters by 
    ///   each one of those.
    /// @dev This method requires less gas than buildWitOracleRequest(string[][]), and 
    /// @dev it's usually preferred when data requests built out of this template
    /// @dev are intended to be used just once in lifetime.    
    function verifyRadonRequest(string[][] calldata args) external returns (Witnet.RadonHash);

    function witOracle() external view returns (address);
}
