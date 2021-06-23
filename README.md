# witnet-ethereum-bridge [![](https://travis-ci.com/witnet/witnet-ethereum-bridge.svg?branch=master)](https://travis-ci.com/witnet/witnet-ethereum-bridge)

`witnet-ethereum-bridge` is an open source implementation of a bridge
from Ethereum to Witnet. This repository provides several contracts:

- The `WitnetRequestBoard` (WRB), which includes all the needed functionality to relay data requests and their results from Ethereum to Witnet and the other way round.
- `WitnetRequestBoardProxy`, that routes Witnet data requests from smart contracts to the appropriate `WitnetRequestBoard` controller.
- `UsingWitnet`, an inheritable client contract that injects methods for interacting with the WRB in the most convenient way.


## WitnetRequestBoardProxy

`WitnetRequestBoardProxy.sol` is a proxy contract that routes Witnet data requests coming from the `UsingWitnet` contract to the appropriate `WitnetRequestBoard` controller. `WitnetRequestBoard` controllers are indexed by the last data request indentifier that each controller had stored before the controller was upgraded. Thus, if controller _a_ was replaced by controller _b_ at id _i_, petitions from _0_ to _i_ will be routed to _a_, while controller _b_ will handle petitions from _i_ onwards.


## WitnetRequestBoard

The `WitnetRequestBoard` contract provides the following methods:

- **postDataRequest**:
  - _description_: posts a data request into the WRB in expectation that it will be relayed and resolved 
  in Witnet with  `msg.value` as reward.
  - _inputs_:
    - *_requestAddress*: the request contract address which includes the request bytecode.
  - output:
    - *_id*: the unique identifier of the data request.

- **upgradeDataRequest**:
  - *description*: increments the reward of a data request by 
  adding more value to it. The new request reward will be increased by `msg.value`.
  - *_inputs*:
    - *_id*: the unique identifier of the data request.

- **reportResult**:
  - _description_: reports the result of a data request in Witnet.
  - _inputs_:
    - *_id*: the unique identifier of the data request.
    - *_dr_Hash*: the unique hash of the request.
    - *_result*: the result itself as `bytes`.

- **readDrBytecode**:
  - _description_: retrieves the bytes of the serialization of one data request from the WRB.
  - _inputs_:
    - *_id*: the unique identifier of the data request.
  - _output_:
    - the data request bytes.

- **readResult**:
  - _description_: retrieves the result (if already available) of one data request from the WRB.
  - _inputs_:
    - *_id*: the unique identifier of the data request.
  - _output_:
    - the result of the data request as `bytes`.

- **readDrTxHash**:
  - _description_: retrieves the data request transaction hash in Witnet (if it has already been included and presented) of one data request from the WRB.
  - _inputs_:
    - *_id*: the unique identifier of the data request.
  - _output_:
    - the data request transaction hash. 

- **requestsCount**:
  - _description_: returns the number of data requests in the WRB.
  - _output_:
    - the number of data requests in the WRB.

## UsingWitnet

The `UsingWitnet` contract injects the following methods into the contracts inheriting from it:

- **witnetPostRequest**:
  - _description_: call to the WRB's `postDataRequest` method to post a 
  data request into the WRB so its is resolved in Witnet with `msg.value` as reward.
  - _inputs_:
    - *_requestAddress*: the request contract address which includes the request bytecode.
  - _output_:
    - *_id*: the unique identifier of the data request.

- **witnetUpgradeRequest**:
  - *description*: increments the reward of a data request by adding more value to it. The new request reward will be increased by `msg.value`.
  - _inputs_:
    - *_id*: the sequential identifier of a request that was posted to Witnet.

- **witnetReadResult**:
  - _description_: call to the WRB's `readResult` method to retrieve
   the result of one data request from the WRB.
  - _inputs_:
    - *_id*:the sequential identifier of a request that was posted to Witnet.
  - _output_:
    - the result of the data request as `bytes`.

- **witnetCheckRequestResolved**:
  - _description_: check if a request has been resolved by Witnet.
  - _inputs_:
    - *_id*: the sequential identifier of a request that has been previously sent to the WitnetRequestBoard.
  - _output_:
    - a boolean telling if the request has been already resolved or not.


## Usage

The `UsingWitnet.sol` contract can be used directly by inheritance:

```solidity

pragma solidity >=0.5.3 <0.9.0;

import "./UsingWitnet.sol";

contract Example is UsingWitnet {

  uint256 drCost = 10;
  addressRequest = /* Here goes the data request serialized bytes. */;

  function myOwnDrPost() public returns(uint256 id) {
    id =  witnetPostDataRequest{value: msg.value}(address(_request));
  }
}
```


## Benchmark

```bash
·------------------------------------------------------|---------------------------|----------------------------·
|        Solc version: 0.6.12+commit.27d51765          ·  Optimizer enabled: true  ·         Runs: 200          │
·······················································|···························|·····························
|  Methods                                                                                                      │
························|······························|·············|·············|·············|···············
|  Contract             ·  Method                      ·  Min        ·  Max        ·  Avg        ·  # calls     │
························|······························|·············|·············|·············|···············
|  WitnetRequestBoard  ·  postDataRequest              ·      124824 ·      166389 ·     156710  ·          27  │
························|······························|·············|·············|·············|···············
|  WitnetRequestBoard  ·  reportResult                 ·       66092 ·       68682 ·      67201  ·           13 │
························|······························|·············|·············|·············|···············
|  WitnetRequestBoard  ·  upgradeDataRequest           ·       32649 ·       38715 ·      36693  ·           6  │
························|······························|·············|·············|·············|···············
|  Deployments                                         ·                                         ·  % of limit  │
·······················································|·············|·············|·············|···············
|  Request                                             ·      193452 ·      338184 ·     296851  ·       4.4 %  │
·······················································|·············|·············|·············|···············
|  WitnetRequestBoard                                  ·      1421528 ·     1442893 ·     1441825 ·      66.5 % │
·------------------------------------------------------|-------------|-------------|-------------|--------------·
```


## License

`witnet-ethereum-bridge` is published under the [MIT license][license].

[license]: https://github.com/witnet/witnet-ethereum-bridge/blob/master/LICENSE
