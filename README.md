# witnet-ethereum-bridge [![](https://travis-ci.com/witnet/witnet-ethereum-bridge.svg?branch=master)](https://travis-ci.com/witnet/witnet-ethereum-bridge)

`witnet/witnet-ethereum-bridge` is an open source implementation of an API that enables Solidity smart contract developers to harness the full power of the [**Witnet Decentralized Oracle Network**](https://docs.witnet.io/overview/concepts/).

This repository provides several deployable contracts:

- `WitnetProxy`, that routes Witnet data requests to a currently active `WitnetRequestBoard` implementation.
- `WitnetRequest`, used as a means to encapsulate CBOR-encoded Witnet RADON scripts.
- `WitnetRequestBoard` (WRB), which implements all required functionality to relay Witnet data requests (i.e. encapsulated [Witnet RADON scripts](https://docs.witnet.io/protocol/data-requests/overview/)) from Ethereum to the Witnet mainnet, as well as to relay Witnet-solved results back to Ethereum.

The repository also provides:

- `UsingWitnet`, an inheritable abstract contract that injects methods for conveniently interacting with the WRB.


## WitnetProxy

`WitnetProxy` is an upgradable delegate-proxy contract that routes Witnet data requests coming from a `UsingWitnet`-inheriting contract to a currently active `WitnetRequestBoard` implementation. 

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


## WitnetRequest

 A `WitnetRequest` is constructed around a `bytes` value containing a well-formed Witnet RADON script data request serialized
 using Protocol Buffers. The `WitnetRequest` base contract provides one single method:

- **`bytecode()`**:
  - _Description_:
    - Returns Witnet RADON script as a CBOR-encoded `bytes`. 


## WitnetRequestBoard

The `WitnetRequestBoard` implements the following functionality:

- **`estimateReward(uint256 _gasPrice)`**:
  - _Description_: 
    - Estimates the minimal amount of reward needed to post a Witnet data request into the WRB, for a given gas price.
  - _Inputs_:
    - `_gasPrice`: the request contract address which includes the Witnet RADON script bytecode.
  - _Returns_:
    - The minimal reward amount. 

- **`destroyResult(uint256 _id)`**:
  - _Description_:
    - Retrieves the Witnet-solved result (if already available) of a previously posted Witnet request, and removes it from the WRB storage.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.
  - _Returns_:
    - The Witnet-solved result of the given data request, as CBOR-encoded `bytes`.
  
- **`postRequest(address _witnetRequest)`**:
  - _Description_: 
    - Posts a Witnet data request into the WRB in the expectation that it will be eventually relayed and resolved 
  by Witnet, with `msg.value` as reward.
  - _Inputs_:
    - `_witnetRequest`: the actual `WitnetRequest` contract address which provided the Witnet RADON script bytecode.
  - _Returns_:
    - *_id*: the unique identifier of the data request.

- **`readRequestBytecode(uint256 _id)`**:
  - _Description_:
    - Retrieves the RADON script bytecode of a previously posted Witnet data request.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.
  - _Returns_:
    - The Witnet RADON script bytecode, as `bytes`.

- **`readResponseWitnetResult(uint256 _id)`**:
  - _Description_:
    - Retrieves the Witnet-solved result (if already available) of a previously posted Witnet request.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.
  - _Returns_:
    - The Witnet-solved result of the given data request, as CBOR-encoded `bytes`.

- **`readResponseWitnetProof(uint256 _id)`**:
  - _Description_:
    - Retrieves the unique hash of the Witnet tally transaction that actually solved the given data request. 
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.
  - _Returns_:
    - The Witnet tally transaction hash, if already solved, or zero if not yet solved.

- **`getNextId()`**:
  - _Description_: returns count of Witnet data requests that have been posted so far within the WRB.

- **`reportResult(uint256 _id, uint256 _txhash, bytes _result)`**:
  - _Description_: 
    - Reports the Witnet-solved result of a previously posted Witnet data request.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted data request.
    - `_txHash`: the unique hash of the Witnet tally transaction that actually solved the given data request.
    - `_result`: the Witnet-solved result of the given data request (CBOR-encoded).

- **`upgradeRequest(uint256 _id)`**:
  - _Description_: increments the reward of a Witnet data request by 
  adding more value to it. The new data request reward will be increased by `msg.value`.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.


## UsingWitnet base contract

The `UsingWitnet` contract injects the following _internal methods_ into the contracts inheriting from it:

- **`witnetPostRequest(WitnetRequest _request)`**:
  - _Description_:
    - Method to be called for posting Witnet data request into the WRB, with provided `msg.value` as reward.
  - _Inputs_:
    - `_witnetRequest`: the Witnet request contract address that provides the Witnet RADON script encoded bytecode.
  - _Returns_:
    - The unique identifier of the Witnet data request just posted to the WRB. 

- **`witnetUpgradeRequest()`**:
  - _Description_:
    - Increments the reward of a previously posted Witnet data request by adding more value to it. The new request reward will be increased by `msg.value`.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.

- **`witnetCheckRequestResolved()`**:
  - _Description_: 
    - Checks if a Witnet data request has already been soled by Witnet network.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.
  - _Returns_:
    - A boolean telling whether the Witnet data request has been already solved, or not.

- **`witnetReadResult(uint256 _id)`**:
  - _Description_:
    - Retrieves the Witnet-solved result of a previously posted Witnet data request.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.
  - _Returns_:
    - The Witnet-solved result of the given data request, as CBOR-encoded `bytes`.

- **`witnetDestroyResult(uint256 _id)`**:
  - _Description_:
    - Retrieves the Witnet-solved result (if already available) of a previously posted Witnet request, and removes it from the WRB storage. Works only if this `UsingWitnet` contract is the one that actually posted the given data request.
  - _Inputs_:
    - `_id`: the unique identifier of a previously posted Witnet data request.
  - _Returns_:
    - The Witnet-solved result of the given data request, as CBOR-encoded `bytes`.


## Usage: harness the power of the Witnet Decentralized Oracle Network

In order to integrate your own smart contracts with the **Witnet** fully-decentralized blockchain, you just need to inherit from the `UsingWitnet` abstract contract:

```solidity
pragma solidity >=0.7.0 <0.9.0;

import "./UsingWitnet.sol";

contract MyWitnetRequest is WitnetRequest {
  constructor() WitnetRequest()
}

contract MyContract is UsingWitnet {
  WitnetRequest myRequest;

  constructor() UsingWitnet(/* WitnetProxy address provided by the Witnet Foundation */) {
    myRequest = new WitnetRequest(hex"/* here goes the Witnet RADON script encoded as serialized bytes. */")
  }

  function myOwnDrPost() public returns(uint256 _drTrackId) {
    _drTrackId = witnetPostRequest{value: msg.value}(myRequest);
  }
}
```

Please, have a look at the [`witnet/witnet-price-feed-examples`](https://github.com/witnet/witnet-price-feed-examples) repository to learn how to compose your own `WitnetRequest` contracts.


## Gas cost benchmark

```bash
·---------------------------------------------|---------------------------|----------------------------·
|     Solc version: 0.8.6+commit.11564f7e     ·  Optimizer enabled: true  ·         Runs: 200          │
··············································|···························|·····························
|  Methods                                                                                             │
·······················|······················|·············|·············|·············|···············
|  Contract            ·  Method              ·  Min        ·  Max        ·  Avg        ·  # calls     ·
·······················|······················|·············|·············|·············|··············|
|  WitnetRequestBoard  ·  destroy             ·          -  ·          -  ·      13582  ·           2  ·
·······················|······················|·············|·············|·············|··············|
|  WitnetRequestBoard  ·  destroyResult       ·      32865  ·      33714  ·      33183  ·           8  ·
·······················|······················|·············|·············|·············|··············|
|  WitnetRequestBoard  ·  initialize          ·          -  ·          -  ·      74032  ·          30  ·
·······················|······················|·············|·············|·············|··············|
|  WitnetRequestBoard  ·  postRequest     ·     144465  ·     196232  ·     164083  ·          33  ·
·······················|······················|·············|·············|·············|··············|
|  WitnetRequestBoard  ·  reportResult        ·      77019  ·      79145  ·      77643  ·          17  ·
·······················|······················|·············|·············|·············|··············|
|  WitnetRequestBoard  ·  upgradeRequest  ·      30083  ·      35221  ·      33508  ·           6  ·
·······················|······················|·············|·············|·············|··············|
|  Deployments                                ·                                         ·  % of limit  ·
··············································|·············|·············|·············|··············|
|  CBOR                                       ·          -  ·          -  ·    1937979  ·      28.8 %  ·
··············································|·············|·············|·············|··············|
|  Witnet                                     ·          -  ·          -  ·    2580558  ·      38.4 %  ·
··············································|·············|·············|·············|··············|
|  WitnetProxy                                ·          -  ·          -  ·     489543  ·       7.3 %  ·
··············································|·············|·············|·············|··············|
|  WitnetRequest                              ·     173312  ·     317566  ·     288728  ·       4.3 %  ·
··············································|·············|·············|·············|··············|
|  WitnetRequestBoard                         ·          -  ·          -  ·    1684529  ·      25.1 %  ·
·---------------------------------------------|-------------|-------------|-------------|--------------|
```


## License

`witnet-ethereum-bridge` is published under the [MIT license][license].

[license]: https://github.com/witnet/witnet-ethereum-bridge/blob/master/LICENSE
