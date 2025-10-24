# Wit/Oracle Solidity Framework -- Contracts, SDK and CLI tools for EVM-compatible chains

The **Wit/Oracle Solidity Framework** allows you to easily interact with the Wit/Oracle contracts framework, as deployed on a wide selection of **EVM-compatible chains**, either from Solidity smart contracts of your own, as well as offchain environments, automation scripts and Web3 apps.

## ✨ Overview

This package contains:

### Solidity contracts

### Javascript library
- A **Javascript library** allowing scripts to introspect the set of supported networks, ABIs, addresses and settings, as well as deployed Radon assets. It provides also wrapping Javascript classes for interacting with the Wit/Oracle Framework artifacts.

### CLI binaries

#### `npx witnet-solidity`
  - List supported EVM ecosystems and chains where the Wit/Oracle Contract Framework is available.
  - List addresses of the Wit/Oracle Framework artifacts for each supported chain.
  - Build, leverage, test and deploy your own customized Witnet-compliant data queries. 
  - Show latest updates of the price feeds subsidized by the Witnet Foundation on each supported chain.
  - Show latest data queries actively pulled from smart contracts via the Wit/Oracle Framework.
  - Show latest randomize requests posted to Wit/Randomness contracts. 
  - Force randomize requests into specific Wit/Randomness contracts. 
  - Show latest data reports recently pushed into specific Witnet-aware consuming contracts. 
  - Push notarized data on Witnet into specific Witnet-aware consuming contracts.
  - Build Solidity contracts capable of interacting with the Wit/Oracle Framework contracts. 

#### `npx witnet`
  - Lorem ipsum.


> *This package imports as a runtime dependency the [**Witnet SDK**](https://github.com/witnet/witnet-toolkit) package, so both the SDK library and the CLI binary (`npx witsdk`) get installed and ready to use right out of the box.*

## 📦 Installation

```bash
$ npm install --save @witnet/solidity
```

### Interact with Wit/Oracle appliances on EVM-compatible networks
  ```typescript
  import { assets, ethers, utils, WitOracle } from "@witnet/ethers"
  ```
### Interact with the Witnet network by using the embedded Witnet SDK library
  ```typescript
  import { Witnet } from "@witnet/sdk"
  ```

## ⚙️ Requirements

- Node.js >= 20
- Sufficient balance of the EVM's gas currency for transacting in your preferred EVM-compatible network.
- Sufficient $WIT balance for notarizing real-world data requests in Witnet. 

## 🔧 Configuration

Both the CLI and the Javascript library can be configured using a **.env** file or by setting this environment variable:
```bash
  ETHRPC_PRIVATE_KEYS=["your_eth_private_key_1", ..., "your_eth_private_key_n"]
```
Additionally, you can settle your preferred ETH/RPC provider when launching the local gateway (see below).

## 🧪 Supported EVM-compatible Networks

> *Please, visit the [Witnet Docs site](https://docs.witnet.io/smart-contracts/supported-chains) to get an up-to-date list of supported EVM chains.*

## 🛠️ Usage

### CLI binary

```bash
$ npx witeth <command> [<args>] [<flags>] [<options>] [--help]
```

> *You need to have a local **ETH/RPC gateway** running in order to get access to extra commands. You will only be able to interact with the Wit/Oracle appliances if you connect to a supported EVM network first.*

----
#### `npx witeth networks`
Lists EVM networks where the Wit/Oracle Contract Framework is supported.

**Flags**:
- `--mainnets`: Just list the mainnets.
- `--testnets`: Just list the testnets.

----
#### `npx witeth gateway <evm_network>`
Launches a local ETH/RPC signing gateway to the specified `evm_network`, listening on port 8545 if no otherwise specified.

**Options**:
  - `--port`: Port where the new gateway should be listening on.
  - `--remote`: URL of the ETH/RPC remote provider to use instead of the gateway's default for the specified network. 

> *Launch a gateway to your preferred EVM network on a different terminal so you can augment the available commands of the `witeth` CLI binary. If you launch the gateway on a port other than default's, you'll need to specify `--port <PORT>` when invoking other commands of the `witeth` binary.*

----
#### `npx witeth accounts`
Lists set of local EVM signing addresses set up in the gateway, as well as their current balance of the EVM's native currency. 

----
#### `npx witeth assets [<radon_assets> ..]`
Shows the Radon assets within your project that have been formally verified and deployed into the connected EVM network. It also allows you to verify and deploy additional Radon assets.

**Flags**:
- `--all`: List all available Radon assets, even if not yet deployed.
- `--decode`: Decode selected Radon assets, using the currently deployed bytecode.
- **`--deploy`**: Deploy or replace the selected assets, on the current EVM network.
- `--dry-run`: Dry-run selected Radon assets, using the currently deployed bytecode (superseded `--decode`).
- `--legacy`: Filter Radon assets to those declared within the **witnet/assets** folder of your project.

**Options**:
- `--module`: Specify the NPM package where to fetch declared Radon assets from (supersedes `--legacy`).
- `--signer`: EVM signer address to use when deploying Radon assets, other than the gateway's default.

----
#### `npx witeth contracts`
Lists addresses of all available Wit/Oracle Framework artifacts.

**Flags**:
- `--templates`: Include parameterized Radon templates deployed specifically for this project, if any.

----
#### `npx witeth priceFeeds`
Shows latest updates of the price feeds supported by the specified Wit/PriceFeeds appliance.

For each price feed the following data is shown:
- The symbol (e.g. Price-ETH/USD-6).
- Last updated price.
- Time elapsed since the last price update.
- API's where price updates are extract from, and aggregated together.

**Flags**:
- `--trace-back`: Trace witnessing acts on Witnet that actually provided latest updates for each price feed.

----
#### `npx witeth queries`
Shows latest Wit/Oracle queries actively pulled from smart contracts.

**Flags**:
- `--voids`: Include queries that got eventually deleted by their respective requesters.
- `--trace-back`: Trace the witnessing acts on Witnet that attended each listed query. 

**Options**:
- `--filter-radHash`: Filter queries referring specified RAD hash.
- `--filter-requester`: Filter queries triggered from the specified EVM address.
- `--since`: List queries since the specified EVM block number (default: -5000).
- `--limit`: Limit number of listed records (default: 64).
- `--offset`: Filter first records before listing.

----
#### `npx witeth randomness`
Shows randomize requests posted on the selected Wit/Randomness appliance. It also allows to force new randomize requests.

**Flags**:
- **`--randomize`**: Pay for a new randomize request.
- `--trace-back`: Trace the witnessing acts on Witnet that ultimately provided randomness for each randomization request.

**Options**:
- `--since`: List randomize requests since the specified EVM block number (default: -5000).
- `--limit`: Limit number of listed records (default: 64).
- `--offset`: Filter first records before listing.
- `--gasPrice`: Max. EVM gas price when requesting a new randomize.
- `--signer`: EVM signer address that will pay for the new randomize, other than gateway's default.

----
#### `npx witeth reports`
Shows verified data reports pushed into `IWitOracleConsumer` contracts. It also allows to push the results of Witnet-notarized queries into consuming contracts (no fees required).

**Flags**:
- `--parse`: Decode the CBOR-encoded data that got reported. 
- `--trace-back`: Trace the notarized query on Witnet that produced the reported data. 

**Options**:
- `--filter-consumer`: Only show data reported into the specified EVM address.
- `--filter-requester`: Only show data reported from the specified EVM address.
- `--since`: List pushed data reports since the specified EVM block number (default: -5000).
- `--limit`: Limit number of listed records (default: 64).
- `--offset`: Filter first records before listing.
- **`--push`**: Push the result to some finalized query in Witnet.
- `--into`: The EVM address where to push the data query result.

---
### Javascript library
> *Please, find Javascript and Typescript code snippets in the [Witnet Docs site](https://docs.witnet.io/).*

## 🧱 Built With
- Axios
- Ethers v6
- [ETH/RPC Gateway](https://npmjs.com/ethrpc-gateway) 
- Node.js
- [Witnet SDK](https://npmjs.com/@witnet/sdk)

## 🔐 Security
- Do not share your private keys.
- Use trusted RPC endpoints when using third-party providers.

## 📚 Documentation
Learn more about Witnet, the $WIT coin and the Wit/Oracle Appliance Framework for smart contracts at:

👉 https://docs.witnet.io 
👉 https://witnet.io 
👉 https://witnet.foundation/

## 🧾 License
MIT © 2025 — Maintained by the [Witnet Project](https://github.com/witnet).
