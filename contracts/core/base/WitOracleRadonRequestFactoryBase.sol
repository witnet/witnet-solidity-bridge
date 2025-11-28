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
        witOracleRadonRequestModalsBuilder = WitOracleRadonRequestFactoryModals(_witOracleRadonRequestModalsBuilder);
        witOracleRadonRequestTemplatesBuilder = WitOracleRadonRequestFactoryTemplates(_witOracleRadonRequestTemplatesBuilder);
    }

    /// ===============================================================================================================
    /// --- Implementation of IWitOracleRadonRequestFactory -----------------------------------------------------------

    function buildRadonRequestModal(
            Witnet.DataSourceRequest calldata modalRequest,
            Witnet.RadonReducer memory crowdAttestationTally
        )
        virtual override
        external 
        returns (IWitOracleRadonRequestModal)
    {
        IWitOracleRadonRegistry _witOracleRadonRegistry = IWitOracle(witOracle).registry();
        bytes32 _modalRetrieve = _witOracleRadonRegistry.verifyDataSource(Witnet.DataSource({
            url: "",
            request: modalRequest
        }));
        bytes15 _crowdAttestationTallyHash = bytes15(_witOracleRadonRegistry.verifyRadonReducer(
            crowdAttestationTally
        ));
        address _modal = witOracleRadonRequestModalsBuilder.determineAddress(
            _modalRetrieve,
            _crowdAttestationTallyHash
        );
        if (_modal.code.length == 0) {
            witOracleRadonRequestModalsBuilder.buildRadonRequestModal(
                _modalRetrieve,
                _crowdAttestationTallyHash
            );
            _checkCloneWasDeployed(_modal);
            emit NewRadonRequestModal(_modal);
        }
        return IWitOracleRadonRequestModal(_modal);
    }

    function buildRadonRequestTemplate(
            bytes32[] memory templateRetrievals,
            Witnet.RadonReducer memory dataSourcesAggregator,
            Witnet.RadonReducer memory crowdAttestationTally
        )
        virtual override
        public
        returns (IWitOracleRadonRequestTemplate)
    {
        IWitOracleRadonRegistry _witOracleRadonRegistry = IWitOracle(witOracle).registry();
        bytes15 _dataSourcesAggregatorHash = bytes15(_witOracleRadonRegistry.verifyRadonReducer(dataSourcesAggregator));
        bytes15 _crowdAttestationTallyHash = bytes15(_witOracleRadonRegistry.verifyRadonReducer(crowdAttestationTally));
        address _template = witOracleRadonRequestTemplatesBuilder.determineAddress(
            templateRetrievals,
            _dataSourcesAggregatorHash,
            _crowdAttestationTallyHash
        );
        if (_template.code.length == 0) {
            witOracleRadonRequestTemplatesBuilder.buildRadonRequestTemplate(
                templateRetrievals,
                _dataSourcesAggregatorHash,
                _crowdAttestationTallyHash
            );
            _checkCloneWasDeployed(_template);
            emit NewRadonRequestTemplate(_template);
        }
        return IWitOracleRadonRequestTemplate(_template);
    }

    function buildRadonRequestTemplate(
            Witnet.DataSource[] calldata dataSources,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        virtual override
        external 
        returns (IWitOracleRadonRequestTemplate)
    {
        return buildRadonRequestTemplate(
            __verifyDataSources(IWitOracle(witOracle).registry(), dataSources),
            dataSourcesAggregator,
            crowdAttestationTally
        );
    }

    function verifyDataSource(Witnet.DataSource calldata dataSource) 
        virtual override public
        returns (bytes32)
    {
        return IWitOracle(witOracle).registry().verifyDataSource(dataSource);
    }

    function verifyDataSources(Witnet.DataSource[] calldata dataSources)
        virtual override public
        returns (bytes32[] memory)
    {
        return __verifyDataSources(
            IWitOracle(witOracle).registry(),
            dataSources
        );
    }

    function verifyRadonRequest(
            Witnet.DataSource calldata dataSource,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        virtual override
        external 
        returns (Witnet.RadonHash)
    {
        IWitOracleRadonRegistry _witOracleRadonRegistry = IWitOracle(witOracle).registry();
        return _witOracleRadonRegistry.verifyRadonRequest(
            Witnet.intoDynArray([
                _witOracleRadonRegistry.verifyDataSource(dataSource)
            ]),
            Witnet.RadonReducer({
                method: Witnet.RadonReducerMethods.Mode,
                filters: new Witnet.RadonFilter[](0)
            }),
            crowdAttestationTally
        );
    }

    function verifyRadonRequest(
            Witnet.DataSource[] calldata dataSources,
            Witnet.RadonReducer calldata dataSourcesAggregator,
            Witnet.RadonReducer calldata crowdAttestationTally
        )
        virtual override external 
        returns (Witnet.RadonHash)
    {
        IWitOracleRadonRegistry _witOracleRadonRegistry = IWitOracle(witOracle).registry();
        return _witOracleRadonRegistry.verifyRadonRequest(
            __verifyDataSources(_witOracleRadonRegistry, dataSources),
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

    function __verifyDataSources(
            IWitOracleRadonRegistry _witOracleRadonRegistry,
            Witnet.DataSource[] calldata _dataSources
        )
        virtual internal 
        returns (bytes32[] memory _ids)
    {
        _ids = new bytes32[](_dataSources.length);
        for (uint _ix; _ix < _ids.length; ++ _ix) {
            _ids[_ix] = _witOracleRadonRegistry.verifyDataSource(_dataSources[_ix]);
        }
    }
}
