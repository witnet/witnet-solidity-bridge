# witnet-ethereum-bridge [![](https://travis-ci.com/witnet/witnet-ethereum-bridge.svg?branch=master)](https://travis-ci.com/witnet/witnet-ethereum-bridge)

`witnet/witnet-ethereum-bridge` is an open source implementation of an API that enables Solidity smart contract developers to harness the full power of the [**Witnet Decentralized Oracle Network**](https://docs.witnet.io/overview/concepts/).

This repository provides several deployable contracts:

- `WitnetParseLib`, helper library useful for parsing Witnet-solved results to previously posted Witnet Data Requests.
- `WitnetProxy`, a delegate-proxy contract that routes Witnet Data Requests to a currently active `WitnetRequestBoard` implementation.
- Multiple implementations of the `WitnetRequestBoard` interface (WRB), which declares all required functionality to relay encapsulated [Witnet Data Requests](https://docs.witnet.io/protocol/data-requests/overview/) from Ethereum to the Witnet mainnet, as well as to relay Witnet-solved results back to Ethereum.

The repository also provides:

- `UsingWitnet`, an inheritable abstract contract that injects methods for conveniently interacting with the WRB.
- `WitnetRequest`, used as a means to encapsulate unmodifiable Witnet Data Requests.
- `WitnetRequestBase`, useful as a base contract to implement your own modifiable Witnet Data Requests.


## **WitnetProxy**

`WitnetProxy` is an upgradable delegate-proxy contract that routes Witnet Data Requests coming from a `UsingWitnet`-inheriting contract to a currently active `WitnetRequestBoard` implementation. 

This table contains all the `WinetProxy` instances that act as entry-points for the latest versions of the `WitnetRequestBoard` approved and deployed by the [**Witnet Foundation**](https://witnet.io), and that actually integrates with the **Witnet mainnet** from the following EVM-compatible blockchains:

  | Blockchain   | Network   | `WitnetProxy` address
  | ------------ | --------- | ---------------------
  | **Ethereum** | Rinkeby   | `` 
  |              | Göerli    | `` 
  |              | Mainnet   | `` 
  | ------------ | --------- | ---------------------
  | **Conflux**  | Testnet   | `` 
  |              | Mainnet   | `` 
  | ------------ | --------- | ---------------------
  | **OMGX.L2**  | Rinkeby   | `` 
  |              | Mainnet   | `` 
  | ------------ | --------- | ---------------------

## **IWitnetRequest**

Used as a means to encapsulate Witnet Data Requests, that can eventually be posted to a `WitnetRequestBoard` implementation. The `bytecode()` of a `IWitnetRequest` must be constructed from the CBOR-encoded serialization of a [Witnet Data Request](https://docs.witnet.io/protocol/data-requests/overview/). The `IWitnetRequest` interface defines two methods:

- **`bytecode()`**:
  - _Description_:
    - Returns Witnet Data Request as a CBOR-encoded `bytes`. 

- **`hash()`**:
  - _Description_:
    - Returns SHA256 hash of Witnet Data Request as CBOR-encoded bytes.

## **WitnetRequestBoard**

From the point of view of a `UsingWitnet` contract, any given `WitnetRequestBoard` will always support the following interfaces:

- **`IWitnetRequestBoardEvents`**
- **`IWitnetRequestBoardRequestor`**
- **`IWitnetRequestBoardView`**

### IWitnetRequestBoardEvents:

- Event **`PostedRequest(uint256 queryId, address from)`**:
  - _Description_: 
    - Emitted when a Witnet Data Request is posted to the WRB.
  - _Arguments_:
    - `queryId`: the query id assigned to this new posting.
    - `from`: the address from which the Witnet Data Request was posted.

- Event **`PostedResult(uint256 queryId, address from)`**:
  - _Description_: 
    - Emitted when a Witnet-solved result is reported to the WRB.
  - _Arguments_:
    - `queryId`: the id of the query the result refers to.
    - `from`: the address from which the result was reported.

- Event **`DeletedQuery(uint256 queryId, address from)`**:
  - _Description_: 
    - Emitted when all data related to given query is deleted from the WRB.
  - _Arguments_:
    - `queryId`: the id of the query that has been deleted.
    - `from`: the address from which the result was reported.    

### IWitnetRequestBoardRequestor:

- **`postRequest(IWitnetRequest _request)`**:
  - _Description_: 
    - Posts a Witnet Data Request into the WRB in the expectation that it will be eventually relayed and resolved 
  by the Witnet decentralized oracle network, with `msg.value` as reward.
  - _Inputs_:
    - `_request`: the actual `IWitnetRequest` contract address which provided the Witnet Data Request bytecode.
  - _Returns_:
    - *_id*: the unique identifier of the data request.

- **`upgradeReward(uint256 _id)`**:
  - _Description_: increments the reward of a Witnet data request by 
  adding more value to it. The new data request reward will be increased by `msg.value`.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.

- **`deleteQuery(uint256 _id)`**:
  - _Description_:
    - Retrieves copy of all Witnet-provided data related to a previously posted request, removing the whole query from the WRB storage.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.
  - _Returns_:
    - The Witnet-solved result of the given data request, as CBOR-encoded `bytes`.

### IWitnetRequestBoardView:

- **`estimateReward(uint256 _gasPrice)`**:
  - _Description_: 
    - Estimates the minimal amount of reward needed to post a Witnet data request into the WRB, for a given gas price.
  - _Inputs_:
    - `_gasPrice`: the gas price for which we need to calculate the rewards.

- **`getNextQueryId()`**:
  - _Description_:
    - Returns next query id to be generated by the Witnet Request Board.

- **`getQueryData(uint256 _queryId)`**:
  - _Description_: 
    - Gets the whole `Witnet.Query` record related to a previously posted Witnet Data Request.
  - _Inputs_:
    - `_queryId`: the unique identifier of the query.

- **`getQueryStatus(uint256 _queryId)`**:
  - _Description_: 
    - Gets current status of the given query.
  - _Inputs_:
    - `_queryId`: the unique identifier of the query.

- **`readRequest(uint256 _queryId)`**:
  - _Description_:
    - Retrieves the whole `Witnet.Request` record referred to a previously posted Witnet Data Request.
  - _Inputs_:
    - `_queryId`: the unique identifier of the query.

- **`readRequestBytecode(uint256 _queryId)`**:
  - _Description_:
    - Retrieves the serialized bytecode of a previously posted Witnet Data Request.
  - _Inputs_:
    - `_queryId`: the unique identifier of the query.
  - _Returns_:
    - The Witnet Data Request bytecode, serialized as `bytes`.

- **`readRequestGasPrice(uint256 _queryId)`**:
  - _Description_:
    - Retrieves the gas price that any assigned reporter will have to pay when reporting result to the referred query.
  - _Inputs_:
    - `_queryId`: the unique identifier of the query.

- **`readRequestReward(uint256 _queryId)`**:
  - _Description_:
    - Retrieves the reward currently set for the referred query.
  - _Inputs_:
    - `_queryId`: the unique identifier of the query.

- **`readResponse(uint256 _queryId)`**:
  - _Description_:
    - Retrieves the whole `Witnet.Response` record referred to a previously posted Witnet Data Request. Fails it the query has not been solved yet.
  - _Inputs_:
    - `_queryId`: the unique identifier of the query.

- **`readResponseTimestamp(uint256 _queryId)`**:
  - _Description_:
    - Retrieves the timestamp in which the result to the referred query was solved by the Witnet DON.
  - _Inputs_:
    - `_queryId`: the unique identifier of a previously posted Witnet data request.

- **`readResponseDrTxHash(uint256 _queryId)`**:
  - _Description_:
    - Retrieves the hash of the Witnet transaction hash that actually solved the referred query.
  - _Inputs_:
    - `_queryId`: the unique identifier of the query.

- **`readResponseReporter(uint256 _queryId)`**:
  - _Description_:
    - Retrieves the address from which the result to the referred query was actually reported.
  - _Inputs_:
    - `_queryId`: the unique identifier of a previously posted Witnet data request.

- **`readResponseResult(uint256 _queryId)`**:
  - _Description_:
    - Retrieves the Witnet-provided CBOR-bytes result to the referred query. Fails it the query has not been solved yet.
  - _Inputs_:
    - `_queryId`: the unique identifier of the query.
  - _Returns_:
    - The Witnet-provided result to the given query, as CBOR-encoded `bytes`.

## **UsingWitnet base contract**

The `UsingWitnet` contract injects the following _internal methods_ into the contracts inheriting from it:

- **`_witnetPostRequest(IWitnetRequest _request)`**:
  - _Description_:
    - Method to be called for posting Witnet data request into the WRB, with provided `msg.value` as reward.
  - _Inputs_:
    - `_request`: the Witnet request contract address that provides the Witnet Data Request encoded bytecode.
  - _Returns_:
    - The unique identifier of the Witnet data request just posted to the WRB. 

- **`_witnetUpgradeReward()`**:
  - _Description_:
    - Increments the reward of a previously posted Witnet data request by adding more value to it. The new request reward will be increased by `msg.value`.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.

- **`_witnetCheckResultAvailability()`**:
  - _Description_: 
    - Checks if a Witnet data request has already been solved by Witnet network.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.
  - _Returns_:
    - A boolean telling whether the Witnet data request has been already solved, or not.

- **`_witnetReadResult(uint256 _id)`**:
  - _Description_:
    - Retrieves the Witnet-solved result of a previously posted Witnet data request.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.
  - _Returns_:
    - The Witnet-solved result of the given data request, as CBOR-encoded `bytes`.

- **`_witnetDeleteQuery(uint256 _id)`**:
  - _Description_:
    - Retrieves the Witnet-solved result (if already available) of a previously posted Witnet request, and removes it from the WRB storage. Works only if this `UsingWitnet` contract is the one that actually posted the given data request.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.
  - _Returns_:
    - The Witnet-solved result of the given data request, as CBOR-encoded `bytes`.

Besides, your contract will have access to the whole Witnet Request Board functionality by means of the immutable **`witnet`** address field.

## **Usage: harness the power of the Witnet Decentralized Oracle Network**

In order to integrate your own smart contracts with the **Witnet** fully-decentralized blockchain, you just need to inherit from the `UsingWitnet` abstract contract:

```solidity
pragma solidity >=0.7.0 <0.9.0;

import "./UsingWitnet.sol";

contract MyContract is UsingWitnet {
  IWitnetRequest myRequest;

  constructor() UsingWitnet(/* here comes the WitnetProxy address provided by the Witnet Foundation */) {
    // TODO
  }

  function myOwnDrPost() public returns(uint256 _drTrackId) {
    _drTrackId = witnetPostRequest{value: msg.value}(myRequest);
  }
}
```

Please, have a look at the [`witnet/truffle-box`](https://github.com/witnet/truffle-box) repository to learn how to compose your own `IWitnetRequest` contracts.

## **Gas cost benchmark**

```bash
·--------------------------------------------------------|---------------------------|-------------|----------------------------·
|          Solc version: 0.8.6+commit.11564f7e           ·  Optimizer enabled: true  ·  Runs: 200  ·  Block limit: 6718946 gas  │
·························································|···························|·············|·····························
|  Methods                                                                                                                      │
·······································|·················|·············|·············|·············|··············|··············
|  Contract                            ·  Method         ·  Min        ·  Max        ·  Avg        ·  # calls     ·  usd (avg)  │
·······································|·················|·············|·············|·············|··············|··············
|  WitnetProxy                         ·  upgradeTo      ·          -  ·          -  ·     121146  ·           1  ·          -  │
·······································|·················|·············|·············|·············|··············|··············
|  WitnetRequestBoardTrustableDefault  ·  deleteQuery    ·      38352  ·      41633  ·      40403  ·           8  ·          -  │
·······································|·················|·············|·············|·············|··············|··············
|  WitnetRequestBoardTrustableDefault  ·  destruct       ·          -  ·          -  ·      13582  ·           2  ·          -  │
·······································|·················|·············|·············|·············|··············|··············
|  WitnetRequestBoardTrustableDefault  ·  initialize     ·          -  ·          -  ·      75077  ·          30  ·          -  │
·······································|·················|·············|·············|·············|··············|··············
|  WitnetRequestBoardTrustableDefault  ·  postRequest    ·     144650  ·     196484  ·     164280  ·          33  ·          -  │
·······································|·················|·············|·············|·············|··············|··············
|  WitnetRequestBoardTrustableDefault  ·  reportResult   ·     119210  ·     121359  ·     119806  ·          18  ·          -  │
·······································|·················|·············|·············|·············|··············|··············
|  WitnetRequestBoardTrustableDefault  ·  upgradeReward  ·      31341  ·      36484  ·      34770  ·           6  ·          -  │
·······································|·················|·············|·············|·············|··············|··············
|  Deployments                                           ·                                         ·  % of limit  ·             │
·························································|·············|·············|·············|··············|··············
|  WitnetDecoderLib                                      ·          -  ·          -  ·    1930600  ·      28.7 %  ·          -  │
·························································|·············|·············|·············|··············|··············
|  WitnetParserLib                                       ·          -  ·          -  ·    2594996  ·      38.6 %  ·          -  │
·························································|·············|·············|·············|··············|··············
|  WitnetProxy                                           ·          -  ·          -  ·     587730  ·       8.7 %  ·          -  │
·························································|·············|·············|·············|··············|··············
|  WitnetRequestBoardTrustableDefault                    ·          -  ·          -  ·    3699603  ·      55.1 %  ·          -  │
·--------------------------------------------------------|-------------|-------------|-------------|--------------|-------------·
```


## **License**

`witnet-ethereum-bridge` is published under the [MIT license][license].

[license]: https://github.com/witnet/witnet-ethereum-bridge/blob/master/LICENSE
