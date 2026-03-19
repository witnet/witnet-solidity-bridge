# Wit/Oracle Solidity Framework

Contracts, wrappers, and CLI tooling for running and integrating the Wit/Oracle stack on EVM-compatible networks.

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/witnet/witnet-solidity-bridge)

## Quick Start By Persona

### For Operators (5 minutes)

1. Install dependencies:

```bash
pnpm install
```

2. List supported chains:

```bash
npx witeth networks
```

3. Start a local signing gateway connected to your target network:

```bash
npx witeth gateway <ecosystem:chain>
```

4. In another terminal, inspect framework contracts in that chain:

```bash
npx witeth framework --verbose
```

5. For deployments or upgrades, use your internal deployment automation/playbook:

```bash
<run your deployment pipeline for ecosystem:chain>
```

### For Solidity Developers (5 minutes)

1. Install package:

```bash
npm install @witnet/solidity
```

2. Browse subsidized feeds:

```bash
npx witeth priceFeeds
```

3. Browse randomness requests:

```bash
npx witeth randomness
```

4. Inspect oracle pull queries and pushed reports:

```bash
npx witeth queries --limit 20
npx witeth reports --limit 20 --parse
```

5. Inspect and dry-run Radon assets:

```bash
npx witeth assets --all --decode
npx witeth assets <assetName> --dry-run
```

### For JavaScript Developers (5 minutes)

1. Install dependencies:

```bash
npm install @witnet/solidity ethers
```

2. Instantiate wrappers from an ethers JsonRpcProvider:

```ts
import { ethers, utils } from "@witnet/solidity";

const provider = new ethers.JsonRpcProvider(process.env.ETH_RPC_URL!);
const framework = await utils.fetchWitOracleFramework(provider);

console.log(Object.keys(framework));
```

3. Build a strongly typed WitOracle wrapper:

```ts
import { WitOracle } from "@witnet/solidity";

const witOracle = await WitOracle.fromEthRpcProvider(provider);
const randomness = await witOracle._getWitRandomness();
console.log(await randomness.getEvmChainId());
```

## Documentation Map

- Operator deep dive: [docs/operator-guide.md](docs/operator-guide.md)
- Solidity deep dive: [docs/solidity-guide.md](docs/solidity-guide.md)
- JavaScript deep dive: [docs/javascript-guide.md](docs/javascript-guide.md)
- CLI appendix (examples, output shape, failures): [docs/cli-appendix.md](docs/cli-appendix.md)

## Operator Guide

### Fine-Tune Contract Implementations By Target Network

Network-specific behavior is controlled by your network metadata, artifact mapping, and deployment specs sources of truth.

Recommended decision flow for WitOracle implementation selection:

1. Start from your default implementation mapping.
2. Add ecosystem override when many chains share behavior.
3. Add chain-level override only when strictly needed.
4. Keep deployment spec changes minimal and explicit.

### Upgrade Framework In An Already Supported Network

Preflight:

```bash
pnpm run fmt
pnpm run compile
```

Run selective upgrade using your internal release process for the targeted artifacts.

Run full upgrade only through your approved change-management process.

Validate upgraded state:

```bash
npx witeth gateway <ecosystem:chain>
npx witeth framework --verbose
```

### Add And Deploy A New Network

1. Add the network to your supported-network catalog using the name pattern ecosystem:chain.
2. Add artifact overrides when defaults are not enough.
3. Add deployment specs for mutables, immutables, dependencies, or libs.
4. Deploy using your approved deployment automation.

5. Verify and smoke-test:

```bash
npx witeth gateway <ecosystem:chain>
npx witeth framework --verbose
npx witeth priceFeeds
npx witeth randomness
```

## Solidity Developer Guide

### Price Feeds

#### List supported price feeds

You can enumerate supported feeds both on-chain and from CLI.

Solidity path:

- Call `IWitPriceFeeds.lookupPriceFeeds()`.
- Return value is `PriceFeedInfo[]`, where each item includes:
- `id`: 32-byte feed id.
- `exponent`: decimals exponent for interpreting price values.
- `symbol`: human-readable caption.
- `mapper`: mapping definition when feed is derived from dependencies.
- `oracle`: oracle target and source identifiers.
- `updateConditions`: heartbeat, deviation, witness, and callback settings.
- `lastUpdate`: last known `Price` (`exponent`, `price`, `deltaPrice`, `timestamp`, `trail`).

CLI path:

- Run `npx witeth priceFeeds`.
- CLI table highlights:
- `ID4`: 4-byte identifier used by native `IWitPriceFeeds` reads.
- `CAPTION`: price feed caption/symbol.
- `FRESHNESS`: relative age of last update (for example, "2 minutes ago").
- `DATA PROVIDERS`: upstream providers or composed dependencies used for the feed.

#### Consume subsidized feeds through WitPriceFeeds

You can read the same subsidized feed through four compatibility paths:

1. Witnet-native interface (`IWitPriceFeeds`)
2. ERC-2362 compatibility (`IERC2362`-style `valueFor(bytes32)`)
3. Pyth-adapted interface (`IWitPyth` methods)
4. Chainlink-adapted interface (create adapter then consume `IWitPythChainlinkAggregator` / Chainlink V3 methods)

##### 1) Witnet-native way (`IWitPriceFeeds`)

Methods:

- `getPrice(ID4 id4)`
- `getPriceNotOlderThan(ID4 id4, uint24 age)`
- `getPriceUnsafe(ID4 id4)`

Arguments:

- `id4`: 4-byte feed identifier, usually derived from caption (for example via `computeID4("Price-ETH/USD-6")`).
- `age`: max accepted staleness in seconds (`getPriceNotOlderThan` only).

Possible reverts:

- `PriceFeedNotFound()` when the feed is not supported.
- `StalePrice()` on stale updates (`getPrice`, `getPriceNotOlderThan`).
- `InvalidGovernanceTarget()` if EMA-governed conditions are unmet for the feed.

Expected return:

- `Price` struct with `exponent`, `price`, `deltaPrice`, `timestamp`, `trail`.
- Effective numeric value is typically interpreted as `price * 10^exponent`.

##### 2) ERC-2362 way (`valueFor(bytes32)`)

Method:

- `valueFor(bytes32 id)`

Arguments:

- `id`: 32-byte feed id (typically from `computeID32(caption)`).

Possible reverts:

- Typically no sanity-check revert for stale/missing values in this path.
- In normal operation, status codes signal health instead of reverting.

Expected return:

- `(int256 value, uint256 timestamp, uint256 status)`.
- Status semantics in current implementation:
- `200`: fresh value.
- `400`: stale value.
- `404`: feed not found / no value yet.

##### 3) Pyth-adapted way (`IWitPyth`)

Methods:

- `getPrice(bytes32 id)`
- `getPriceNotOlderThan(bytes32 id, uint64 age)`
- `getPriceUnsafe(bytes32 id)`
- `getEmaPrice(bytes32 id)`
- `getEmaPriceNotOlderThan(bytes32 id, uint64 age)`
- `getEmaPriceUnsafe(bytes32 id)`

Arguments:

- `id`: 32-byte feed id (`IWitPyth.ID`, backed by `bytes32`).
- `age`: max accepted staleness in seconds for `*NotOlderThan` variants.

Possible reverts:

- `PriceFeedNotFound()` when feed is unsupported.
- `StalePrice()` on stale values in sanity-checked variants.
- `InvalidGovernanceTarget()` for invalid EMA/governance configuration.

Expected return:

- `PythPrice` struct: `price` (`int64`), `conf` (`uint64`), `expo` (`int32`), `publishTime` (`uint`).
- `Unsafe` variants prioritize availability over freshness guarantees.

##### 4) Chainlink-adapted way (`IWitPythChainlinkAggregator`)

Flow:

1. Call `IWitPriceFeeds.createChainlinkAggregator(string caption)`.
2. Use returned aggregator address through `IWitPythChainlinkAggregator` (which extends Chainlink V3 interface).

Key methods after creation:

- Chainlink V3 reads: `latestRoundData()`, `getRoundData(uint80)`, `decimals()`, `description()`, `version()`.
- Adapter metadata: `id4()`, `priceId()`, `symbol()`, `witOracle()`.

Arguments:

- `caption`: feed caption used in WitPriceFeeds (for example `Price-ETH/USD-6`).
- `roundId`: Chainlink-compatible round selector when using `getRoundData`.

Possible reverts:

- `createChainlinkAggregator` reverts if caption is not supported.
- Read methods may bubble up underlying feed lookup failures.

Expected return:

- Chainlink-compatible tuple from round methods:
- `(roundId, answer, startedAt, updatedAt, answeredInRound)`.
- `answer` is the price value adapted to Chainlink-style consumers.

##### Compact Solidity Example (all 4 paths)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IWitPriceFeeds, IWitPriceFeedsTypes } from "@witnet/solidity/contracts/interfaces/IWitPriceFeeds.sol";
import { IWitPyth } from "@witnet/solidity/contracts/interfaces/legacy/IWitPyth.sol";
import { IWitPythChainlinkAggregator } from "@witnet/solidity/contracts/interfaces/legacy/IWitPythChainlinkAggregator.sol";

interface IERC2362 {
  function valueFor(bytes32 id) external view returns (int256 value, uint256 timestamp, uint256 status);
}

contract FeedReadExamples {
  IWitPriceFeeds public immutable feeds;

  constructor(address feedsAddress) {
    feeds = IWitPriceFeeds(feedsAddress);
  }

  // 1) Witnet-native
  function readNative(bytes4 id4)
    external
    view
    returns (IWitPriceFeedsTypes.Price memory checked, IWitPriceFeedsTypes.Price memory unsafe_)
  {
    checked = feeds.getPrice(IWitPriceFeedsTypes.ID4.wrap(id4));
    unsafe_ = feeds.getPriceUnsafe(IWitPriceFeedsTypes.ID4.wrap(id4));
  }

  // 2) ERC-2362 compatibility
  function readErc2362(bytes32 id32) external view returns (int256 value, uint256 timestamp, uint256 status) {
    return IERC2362(address(feeds)).valueFor(id32);
  }

  // 3) Pyth-adapted compatibility
  function readPyth(bytes32 id32)
    external
    view
    returns (IWitPyth.PythPrice memory spot, IWitPyth.PythPrice memory ema)
  {
    IWitPyth.ID id = IWitPyth.ID.wrap(id32);
    spot = feeds.getPriceNotOlderThan(id, 300);
    ema = feeds.getEmaPriceUnsafe(id);
  }

  // 4) Chainlink-adapted compatibility
  function createAndReadChainlink(string calldata caption)
    external
    returns (address aggregator, int256 answer, uint256 updatedAt)
  {
    aggregator = feeds.createChainlinkAggregator(caption);
    (, answer, , updatedAt, ) = IWitPythChainlinkAggregator(aggregator).latestRoundData();
  }
}
```

##### Production pattern: read from pre-created Chainlink adapter

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IWitPythChainlinkAggregator } from "@witnet/solidity/contracts/interfaces/legacy/IWitPythChainlinkAggregator.sol";

contract FeedReadChainlinkOnly {
  IWitPythChainlinkAggregator public immutable adapter;

  constructor(address adapterAddress) {
    adapter = IWitPythChainlinkAggregator(adapterAddress);
  }

  function readLatest()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return adapter.latestRoundData();
  }

  function metadata()
    external
    view
    returns (bytes4 id4, bytes32 priceId, string memory symbol, address witOracle, uint8 decimals)
  {
    return (adapter.id4(), adapter.priceId(), adapter.symbol(), adapter.witOracle(), adapter.decimals());
  }
}
```

#### Permissionless reporting under your own premises

See the @witnet/price-feeds README:

- https://github.com/witnet/price-feeds/blob/master/README.md

#### Get your contracts reported when a new price update is available

See the @witnet/price-feeds README:

- https://github.com/witnet/price-feeds/blob/master/README.md

#### Introspect data sources, scripts, and history via CLI

See the @witnet/price-feeds README:

- https://github.com/witnet/price-feeds/blob/master/README.md

### Randomness

#### Pull randomness from a smart contract

Call randomize on the WitRandomness contract from your contract flow, then consume finalized entropy once available.

#### Pull randomness from off-chain

```bash
npx witeth randomness --target <wit_randomness_address> --randomize --signer <evm_address>
npx randomizer --target <wit_randomness_address>
```

#### Callback-based randomness consumers

Pattern:

1. Clone a WitRandomness instance:

```bash
npx witeth randomness --target <wit_randomness_address> --clone --signer <evm_address>
```

2. Trigger randomization by bot or by randomize calls.
3. Implement IWitRandomnessConsumer callback entrypoint in your consumer contract.

### Custom Feeds (Radon Requests)

Radon Request is the programmable query definition in Witnet: sources, transforms, aggregation, and commit/reveal consensus knobs.

#### Build invariable and parameterized requests

- Solidity path: verify and refer requests from contracts in this framework.
- JavaScript path: compose assets using @witnet/sdk.

#### Dry-run, verify, and inspect from CLI

```bash
npx witeth assets --all --decode
npx witeth assets <request_or_template> --dry-run
npx witeth assets <request_or_template> --deploy
```

#### Pull by verified RAD hash and validate pushed updates

Use queries and reports commands to inspect pull and push workflows by RAD hash:

```bash
npx witeth queries --filter-radHash <rad_hash_fragment>
npx witeth reports --filter-radHash <rad_hash_fragment> --parse
```

## JavaScript Developer Guide

### Functions in @witnet/solidity/utils

Commonly used functions:

- getNetworkTagsFromString
- fetchWitOracleFramework
- fetchEvmNetworkFromProvider
- getEvmNetworkAddresses
- getEvmNetworkByChainId
- getEvmNetworkId
- getEvmNetworkSymbol
- getEvmNetworks
- isEvmNetworkMainnet
- isEvmNetworkSupported
- abiDecodeQueryStatus
- abiEncodeDataPushReport
- abiEncodeDataPushReportMessage
- abiEncodeDataPushReportDigest
- abiEncodePriceFeedUpdateConditions
- abiEncodeWitOracleQueryParams
- abiEncodeRadonAsset

### Instantiate wrappers for all available artifacts from a provider

```ts
import { ethers, utils } from "@witnet/solidity";

const provider = new ethers.JsonRpcProvider(process.env.ETH_RPC_URL!);
const framework = await utils.fetchWitOracleFramework(provider);

for (const [name, artifact] of Object.entries(framework)) {
  console.log(name, artifact.address, artifact.class, artifact.semVer);
}
```

### Build, check, dry-run, and introspect Radon requests

1. Build invariable or parameterized Radon definitions with @witnet/sdk.
2. Use CLI for decode and dry-run checks.
3. Inspect trace-back for feeds, queries, and reports to validate end-to-end behavior.

## CLI Reference

### Core commands

- npx witeth networks
- npx witeth gateway <ecosystem:chain>
- npx witeth accounts
- npx witeth framework
- npx witeth assets
- npx witeth priceFeeds
- npx witeth queries
- npx witeth randomness
- npx witeth reports
- npx randomizer

### Useful flags and options

- --trace-back, --parse, --randomize, --clone, --deploy, --dry-run, --decode, --verbose
- --target, --signer, --filter-radHash, --filter-requester, --filter-consumer, --since, --limit, --offset, --push, --into

## Troubleshooting

- Unsupported chain id in CLI usually means your gateway is connected to a network that is not yet configured as supported.
- Missing framework artifacts generally means the selected network has no deployed addresses configured or deployment is incomplete.
- Upgrade no-op with selected artifacts usually indicates same implementation bytecode/version is already active.
- PriceFeeds wrapper fallback to legacy can happen on older deployments that only expose legacy interfaces.

## License

MIT
