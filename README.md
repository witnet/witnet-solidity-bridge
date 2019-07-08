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
    - *_dr*: the data request bytes.
    - *_tallyReward*: the reward from the value sent to the contract
     that is destinated to reward the result inclusion.
  - output:
    - *_id*: the id of the dr.

- **upgradeDataRequest**:
  - *description*: updates the total reward of the data request by 
  adding more value to it.
  - *_inputs*:
    - *_id*: the id of the data request.
    - *_tallyReward*: the new reward 

- **claimDataRequests**:
  - _description_: claims the data requests specified by the input ids
   and assigns the potential data request inclusion reward to the 
   claiming pkh.
  - _inputs_:
    - *_ids*: the ids of the data request.
    - *_poe*: the proof of eligibility of the bridge node to claim 
    data requests

- **reportDataRequestInclusion**:
  - _description_: reports the proof of inclusion to unlock the 
  inclusion reward to the claiming pkh.
  - _inputs_:
    - *_id*: the id of the data request.
    - *_poi*: the proof of inclusion of the data requests in one block 
    in Witnet.
    - *_index*: index in the merkle tree.
    - *_blockHash*: the hash of the block in which the data request 
    was inserted.
- **reportResult**:
  - _description_: reports the result of a data request in Witnet.
  - _inputs_:
    - *_id*: the id of the data request.
    - *_poi*: the proof of inclusion of the result in one block in Witnet.
    - *_index*: index in the merkle tree.
    - *_blockHash*: the hash of the block in which the result (tally) 
    was inserted.
    - *_result*: the result itself.
- **readDataRequest**:
  - _description_: reads the bytes of one dr in the WBI.
  - _inputs_:
    - *_id*: the id of the data request.
  - _output_:
    - the data request bytes.
- **readResult**:
  - _description_: reads the result of one dr in the WBI.
  - _inputs_:
    - *_id*: the id of the data request.
  - _output_:
    - the result of the data request.

The Block Relay has the following methods:

- **postNewBlock**:
  - _description_: post new block in the block relay.
  - _inputs_:
    - *_blockHash*: Hash of the block header.
    - *_drMerkleRoot*: merkle root belonging to the data requests.
    - *_tallyMerkleRoot*: merkle root belonging to the tallies.
- **readDrMerkleRoot**:
  - _description_: read the DR merkle root.
  - _inputs_:
    - *_blockHash*: hash of the block header.
  - _output_:
    - merkle root for the DR in the block header.
- **readTallyMerkleRoot**:
  - _description_: read the tally merkle root.
  - _inputs_:
    - *_blockHash*: hash of the block header.
  - _output_:
    - merkle root for the tallies in the block header.
  
The UsingWitnet provides the following methods:

- **witnetPostDataRequest**:
  - _description_: call to the WBI method `postDataRequest` to posts a 
  data request in the WBI to be resolved in Witnet with total reward 
  specified in msg.value.
  - _inputs_:
    - *_dr*: the data request bytes.
    - *_tallyReward*: the reward from the value sent to the contract
     that is destinated to reward the result inclusion.
  - _output_:
    - *_id*: the id of the dr.

- **witnetUpgradeDataRequest**:
  - _description_: call to the WBI method `upgradeDataRequest` to updates 
  the total reward of the data request by adding more value to it.
  - _inputs_:
    - *_id*: the id of the data request.
    - *_tallyReward*: the new reward 

- **witnetReadResult**:
  - _description_: call to the WBI method `readResult` to reads
   the result of one dr in the WBI.
  - _inputs_:
    - *_id*: the id of the data request.
  - _output_:
    - the result of the data request.

## Known limitations:

- `block relay` is centralized at the moment (only the deployer of the contract is able to push blocks). In the future incentives will be established to achieve a decentralized block header reporting.
- `verify_poe` is still empty. Proof of eligibility verification trough
 VRF should be implemented.

- `verify_poi` is still empty. Once `block relay` is ready, Proof of 
inclusion should be implemented.


## Usage

## License

`witnet-ethereum-bridge` is published under the [MIT license][license].

[license]: https://github.com/witnet/witnet-ethereum-bridge/blob/master/LICENSE
