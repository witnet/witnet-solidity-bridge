# witnet-ethereum-bridge [![](https://travis-ci.com/witnet/witnet-ethereum-bridge.svg?branch=master)](https://travis-ci.com/witnet/witnet-ethereum-brdige)

`witnet-ethereum-bridge` is an open source implementation of a bridge 
from Ethereum to Witnet. This repository provides two contracts. 
The `Witnet Bridge Interface`(WBI), which provides all the needed 
functionality to bridge data requests from Ethereum to Witnet, and 
`UsingWitnet`, a client contract that aims at facilitating developers 
the connection with the WBI.


The WitnetBridgeInterface provides the following methods:

- **postDataRequest**:
  - _description_: posts a data request in the WBI to be resolved 
  in Witnet with total reward specified in msg.value.
  - _inputs_:
    - _dr_: the data request bytes.
    - _tallie_reward_: the reward from the value sent to the contract
     that is destinated to reward the result inclusion.
  - output:
    - _id_: the id of the dr.

- **upgradeDataRequest**:
  - _description_: updates the total reward of the data request by 
  adding more value to it.
  - _inputs_:
    - id: the id of the data request.
    - _tallie_reward_: the new reward 

- **claimDataRequests**:
  - _description_: claims the data requests specified by the input ids
   and assigns the potential data request inclusion reward to the 
   claiming pkh.
  - _inputs_:
    - _ids_: the ids of the data request.
    - _poe_: the proof of eligibility of the bridge node to claim 
    data requests

- **reportDataRequestInclusion**:
  - _description_: reports the proof of inclusion to unlock the 
  inclusion reward to the claiming pkh.
  - _inputs_:
    - _id_: the id of the data request.
    - _poi_: the proof of inclusion of the data requests in one block 
    in Witnet.
    - *block_hash*: the hash of the block in which the data request 
    was inserted.
- **reportResult**:
  - _description_: reports the result of a data request in Witnet.
  - _inputs_:
    - _id_: the id of the data request.
    - _poi_: the proof of inclusion of the result in one block in Witnet.
    - *block_hash*: the hash of the block in which the result (tallie) 
    was inserted.
    - *result*: the result itself.
- **readDataRequest**:
  - *description*: reads the bytes of one dr in the WBI.
  - *inputs*:
    - *id*: the id of the data request.
  - *output*:
    - the data request bytes.
- **readResult**:
  - *description*: reads the result of one dr in the WBI.
  - *inputs*:
    - *id*: the id of the data request.
  - *output*:
    - the result of the data request.
- **verifyPoe**:
  - TBD
- **verifyPoi**:
  - TBD
  
The UsingWitnet provides the following methods:

- **witnetPostDataRequest**:
  - _description_: call to the WBI method `postDataRequest` to posts a 
  data request in the WBI to be resolved in Witnet with total reward 
  specified in msg.value.
  - _inputs_:
    - _dr_: the data request bytes.
    - _tallie_reward_: the reward from the value sent to the contract
     that is destinated to reward the result inclusion.
  - output:
    - _id_: the id of the dr.

- **witnetUpgradeDataRequest**:
  - _description_: call to the WBI method `upgradeDataRequest` to updates 
  the total reward of the data request by adding more value to it.
  - _inputs_:
    - id: the id of the data request.
    - _tallie_reward_: the new reward 

- **witnetReadResult**:
  - *description*: call to the WBI method `readResult` to reads
   the result of one dr in the WBI.
  - *inputs*:
    - *id*: the id of the data request.
  - *output*:
    - the result of the data request.

## Known limitations:

- `verify_poe` is still empty. Proof of eligibility verification trough
 VRF should be implemented.

- `block relay` is missing.

- `verify_poi` is still empty. Once `block relay` is ready, Proof of 
inclusion should be implemented.


## Usage

## License

`witnet-ethereum-bridge` is published under the [MIT license][license].

[license]: https://github.com/witnet/witnet-ethereum-bridge/blob/master/LICENSE
