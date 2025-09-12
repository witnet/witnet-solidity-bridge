// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "../../WitOracleRadonRequestFactory.sol";

import "./WitOracleRadonRequestFactoryModals.sol";
import "./WitOracleRadonRequestFactoryTemplates.sol";

abstract contract WitOracleRadonRequestFactoryBase
    is
        WitOracleRadonRequestFactory
{
    using Witnet for Witnet.RadonHash;

    /// @notice Reference to the Witnet Request Board that all templates built out from this factory will refer to.
    address immutable public override witOracle;
    
    IWitOracleRadonRegistry immutable internal __witOracleRadonRegistry;
    
    WitOracleRadonRequestFactoryModals immutable public witOracleRadonRequestModalsBuilder;
    WitOracleRadonRequestFactoryTemplates immutable public witOracleRadonRequestTemplatesBuilder;

    constructor(
            address _witOracleRadonRequestModalsBuilder,
            address _witOracleRadonRequestTemplatesBuilder
        )
    {
        witOracle = IWitOracleAppliance(_witOracleRadonRequestModalsBuilder).witOracle();
        _require(
            witOracle != address(0) 
                && witOracle.code.length > 0
                && witOracle == IWitOracleAppliance(_witOracleRadonRequestTemplatesBuilder).witOracle(),
            "invalid builders"
        );
        __witOracleRadonRegistry = IWitOracle(witOracle).registry();
        witOracleRadonRequestModalsBuilder = WitOracleRadonRequestFactoryModals(_witOracleRadonRequestModalsBuilder);
        witOracleRadonRequestTemplatesBuilder = WitOracleRadonRequestFactoryTemplates(_witOracleRadonRequestTemplatesBuilder);
    }

    /// ===============================================================================================================
    /// --- Implementation of IWitOracleRadonRequestFactory -----------------------------------------------------------

    function buildRadonRequestModal(
            DataSourceRequest calldata commonDataRequest,
            Witnet.RadonReducer memory crowdAttestationTally
        )
        virtual override
        external 
        returns (IWitOracleRadonRequestModal)
    {
        bytes32 _commonRetrievalHash = __witOracleRadonRegistry.verifyRadonRetrieval(
            commonDataRequest.method,
            "",
            commonDataRequest.body,
            commonDataRequest.headers,
            commonDataRequest.script
        );
        bytes15 _crowdAttestationTallyHash = bytes15(__witOracleRadonRegistry.verifyRadonReducer(
            crowdAttestationTally
        ));
        address _modal = witOracleRadonRequestModalsBuilder.determineAddress(
            _commonRetrievalHash,
            _crowdAttestationTallyHash
        );
        if (_modal.code.length == 0) {
            witOracleRadonRequestModalsBuilder.buildRadonRequestModal(
                _commonRetrievalHash,
                _crowdAttestationTallyHash
            );
            _checkCloneWasDeployed(_modal);
            emit NewRadonRequestModal(_modal);
        }
        return IWitOracleRadonRequestModal(_modal);
    }

    function buildRadonRequestTemplate(
            bytes32[] memory radonRetrieveHashes,
            Witnet.RadonReducer memory dataSourcesAggregator,
            Witnet.RadonReducer memory crowdAttestationTally
        )
        virtual override
        public
        returns (IWitOracleRadonRequestTemplate)
    {
        bytes15 _dataSourcesAggregatorHash = bytes15(__witOracleRadonRegistry.verifyRadonReducer(dataSourcesAggregator));
        bytes15 _crowdAttestationTallyHash = bytes15(__witOracleRadonRegistry.verifyRadonReducer(crowdAttestationTally));
        address _template = witOracleRadonRequestTemplatesBuilder.determineAddress(
            radonRetrieveHashes,
            _dataSourcesAggregatorHash,
            _crowdAttestationTallyHash
        );
        if (_template.code.length == 0) {
            witOracleRadonRequestTemplatesBuilder.buildRadonRequestTemplate(
                radonRetrieveHashes,
                _dataSourcesAggregatorHash,
                _crowdAttestationTallyHash
            );
            _checkCloneWasDeployed(_template);
            emit NewRadonRequestTemplate(_template);
        }
        return IWitOracleRadonRequestTemplate(_template);
    }

    function buildRadonRequestTemplate(
            DataSource[] calldata dataSources,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        virtual override
        external 
        returns (IWitOracleRadonRequestTemplate)
    {
        bytes32[] memory _radonRetrieveHashes = new bytes32[](dataSources.length);
        for (uint _ix; _ix < dataSources.length; ++ _ix) {
            DataSourceRequest memory _request = dataSources[_ix].request;
            _radonRetrieveHashes[_ix] = __witOracleRadonRegistry.verifyRadonRetrieval(
                _request.method,
                dataSources[_ix].url,
                _request.body,
                _request.headers,
                _request.script
            );
        }
        return buildRadonRequestTemplate(
            _radonRetrieveHashes,
            dataSourcesAggregator,
            crowdAttestationTally
        );
    }


    /// ===============================================================================================================
    /// --- Internal virtual methods ----------------------------------------------------------------------------------

    function _checkCloneWasDeployed(address _clone) virtual internal view {
        _require(
            _clone.code.length > 0,
            "cannot clone"
        );
    }
}
