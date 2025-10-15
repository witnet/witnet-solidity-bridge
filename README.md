# witnet-solidity

Solidity source code of the smart contracts composing the **Witnet EVM Bridge** framework. This framework enables smart contracts operating in a long range of EVM-compatible chains to interact with the [Witnet Oracle Blockchain](https://witnet.io) for retrieving and aggregating offchain public data, or as an entropy source for randomness generation.

## Install the package

`$ pnpm install`

## Deploying the Witnet EVM Bridge on a new chain

### Pre-assessment

Should any artifact require customized contract implementations:

- Please add source files accordingly to `contracts/core/customs`.

- Set up new artifact names, and eventual new construction parameters, if required, to `settings/artifacts` and `settings/specs`, respectively. 

- Run regression tests: `$ pnpm run test`


### Prepare the environment

- Add a new network configuration to `settings/networks`. The network name should follow the pattern `<ecosystem>:<chain-name>`.

- Make sure you run an ETH/RPC provider for the specified `host` and `port`, capable of intercepting `eth_sendTransaction` calls (e.g. [web3-ethrpc-gateway](https://github.io/witnet/web3-jsonrpc-gateway)).

### Run the script

`$ pnpm run migrate <ecosytem>:<chain-name>`

## Upgrding the Witnet EVM Bridge on an existing chain

When modifying the existing source code, or the contents of `settings/artifacts` or `settings/specs`, you may need to upgrade some of the artifacts on certain networks. Just add the `--artifacts` parameter and a comma-separated list of the artifacts you need to upgrade. For instance:

`$ pnpm run migrate <ecosystem>:<chain-name> WitnetErrorsLib,WitnetPriceFeeds`

When specifying deployable library artifacts, the depending contracts will be attempted to be upgraded as well.

With respect to deployable contracts, you shall be asked to confirm manually before actually performing a contract upgrade. You can automate all potentially involved upgrades by adding the parameter `--upgrade-all`. 

Reasons for an upgrade to fail:
- You have no credentials.
- You're attempting to upgrade a contract with the same implementation logic as it currently has. 
- The parameters passed to the upgrade call, as specified in `settings/specs` are not accepted for some reason (see actual revert message for further info).

## Package exported modules

### `require("witnet-solidity-bridge")`
Javacript methods and resources:

- List of supported EVM ecosystems:
    - `supportedEcosystems()`
- List of supported EVM chains:
    - `supportedNetworks()`
- WEB addresses at a given chain:
    - `getAddresses(network)`
- WEB artifacts:
    - `assets.WitnetOracle`
    - `assets.WitnetPriceFeeds`
    - `assets.WitnetPriceRouteSolver`
    - `assets.WitnetRequest`
    - `assets.WitnetRequestBytecodes`
    - `assets.WitnetRequestFactory`
    - `assets.WitnetRequestTemplate`
    - `assets.WitnetUpgrableBase`

### `require("witnet-solidity-bridge/utils")`

Javascript utils methods:

- `fromAscii(str)`
- `getRealmNetworkFromArgs()`
- `getRealmNetworkFromString()`
- `getWitnetArtifactsFromArgs()`
- `getWitnetRequestMethodString(method)`
- `isDryRun(network)`
- `isNullAddress(addr)`
- `padLeft(str, char, size)`
- `prompt(text)`
- `readJsonFromFile(filename)`
- `overwriteJsonFile(filname, extra)`
- `traceHeader(header)`
- `traceTx(tx)`
- `traceVerify(network, verifyArgs)`

