// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./IWitOracleRequest.sol";

interface IWitOracleRequestTemplate {

    /// Builds a WitOracleRequest instance that will provide the bytecode and RAD 
    /// hash of some Witnet-compliant Radon Request, provably made out of the 
    /// data sources, aggregate and tally Radon Reducers that compose this instance.
    /// Reverts if the ranks of passed array don't match either the number of this template's 
    /// data sources, or the number of required parameters by each one of those.
    /// @dev Produced addresses are counter-factual to the template address and the given values.
    function buildWitOracleRequest (string[][] calldata args) external returns (IWitOracleRequest);

    /// Builds a WitOracleRequest instance by specifying one single parameter value
    /// that will be equally applied to all the template's data sources.
    /// Reverts if any of the underlying data sources requires more than just one parameter.
    /// @dev Produced addresses are counter-factual to the template address and the given value.
    function buildWitOracleRequest (string calldata singleArgValue) external returns (IWitOracleRequest);

    /// Returns an array of integers telling the number of parameters required 
    /// by every single data source (i.e. Radon Retrievals) that compose this 
    /// WitOracleRequestTemplate. The length of the returned array tells the number 
    /// of data sources that compose this instance.
    function getArgsCount() external view returns (uint256[] memory);

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

    /// Returns the array of one or more parameterized data sources that compose 
    /// this WitOracleRequestTemplate.
    function getRadonRetrievals() external view returns (Witnet.RadonRetrieval[] memory);

    /// Returns the expected data type produced by successful resolutions of 
    /// any WitOracleRequest that gets built out of this WitOracleRequestTemplate.
    function getResultDataType() external view returns (Witnet.RadonDataTypes); 

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
    function verifyRadonRequest(string[][] calldata args) external returns (bytes32);

    /// Verifies into the bounded WitOracle's registry the actual bytecode
    /// and RAD hash of the Witnet-compliant Radon Request that gets provably
    /// made out as a result of applying the given parameter value to the underlying
    /// data sources, aggregate and tally reducers that compose this template. 
    /// While no actual WitOracleRequest instance gets constructed, the returned value
    /// will be accepted as a valid RAD hash on the bounded WitOracle contract from now on.
    /// Reverts if any of the underlying data sources requires more than just one parameter.
    /// @dev This method requires less gas than buildWitOracleRequest(string), and 
    /// @dev it's usually preferred when data requests built out of this template
    /// @dev are intended to be used just once in lifetime.
    function verifyRadonRequest(string calldata singleArgValue) external returns (bytes32);

    /// If built out of an upgradable factory, returns the SemVer tag of the 
    /// factory implementation at the time when this WitOracleRequestTemplate got built.
    function version() external view returns (string memory);
}
