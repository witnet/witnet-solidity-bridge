# Solidity Developer Guide

This guide covers integration patterns for Price Feeds, Randomness, and custom Radon-based requests.

## 1. Price Feeds

## 1.1 List supported price feeds

You can enumerate supported feeds both from Solidity and from CLI.

Solidity path:

- Call `IWitPriceFeeds.lookupPriceFeeds()`.
- Return value is `PriceFeedInfo[]`, where each item includes:
- `id`, `exponent`, `symbol`, `mapper`, `oracle`, `updateConditions`, `lastUpdate`.

CLI path:

- Run `npx witeth priceFeeds`.
- CLI table highlights:
- `ID4`: 4-byte feed id.
- `CAPTION`: feed caption.
- `FRESHNESS`: relative age of latest update.
- `DATA PROVIDERS`: source providers or mapped dependencies.

## 1.2 Consume subsidized feeds

Use WitPriceFeeds to consume subsidized feeds through four compatible read paths.

### Witnet-native way (`IWitPriceFeeds`)

Methods:

- `getPrice(ID4 id4)`
- `getPriceNotOlderThan(ID4 id4, uint24 age)`
- `getPriceUnsafe(ID4 id4)`

Arguments:

- `id4`: 4-byte feed identifier.
- `age`: max allowed staleness in seconds.

Reverts:

- `PriceFeedNotFound()`.
- `StalePrice()` for stale values in sanity-checked methods.
- `InvalidGovernanceTarget()` for invalid EMA/governance setup.

Returns:

- `Price` struct: `exponent`, `price`, `deltaPrice`, `timestamp`, `trail`.

### ERC-2362 way (`valueFor(bytes32)`)

Method:

- `valueFor(bytes32 id)`

Arguments:

- `id`: 32-byte feed id.

Reverts:

- Usually status-driven rather than revert-driven for stale/missing values.

Returns:

- `(int256 value, uint256 timestamp, uint256 status)` where current implementation uses:
- `200` fresh, `400` stale, `404` not found.

### Pyth-adapted way (`IWitPyth`)

Methods:

- `getPrice(bytes32 id)`
- `getPriceNotOlderThan(bytes32 id, uint64 age)`
- `getPriceUnsafe(bytes32 id)`
- `getEmaPrice(bytes32 id)`
- `getEmaPriceNotOlderThan(bytes32 id, uint64 age)`
- `getEmaPriceUnsafe(bytes32 id)`

Arguments:

- `id`: `bytes32` price id.
- `age`: max accepted staleness in seconds.

Reverts:

- `PriceFeedNotFound()`.
- `StalePrice()` in sanity-checked methods.
- `InvalidGovernanceTarget()` for EMA/governance incompatibilities.

Returns:

- `PythPrice`: `price`, `conf`, `expo`, `publishTime`.

### Chainlink-adapted way (`IWitPythChainlinkAggregator`)

Flow:

1. Create adapter with `IWitPriceFeeds.createChainlinkAggregator(string caption)`.
2. Read through Chainlink-compatible methods on returned adapter.

Methods:

- `latestRoundData()`
- `getRoundData(uint80 roundId)`
- `decimals()`, `description()`, `version()`
- `id4()`, `priceId()`, `symbol()`, `witOracle()`

Arguments:

- `caption`: feed caption when creating adapter.
- `roundId`: round id for historical reads.

Reverts:

- Adapter creation reverts if caption is unsupported.
- Read calls may bubble up underlying feed lookup failures.

Returns:

- Chainlink tuple `(roundId, answer, startedAt, updatedAt, answeredInRound)`.

### Compact Solidity example (all 4 paths)

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

### Production pattern: read from pre-created Chainlink adapter

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

## 1.3 Get your contracts reported when a new price update is available

See the @witnet/price-feeds README:

- https://github.com/witnet/price-feeds/blob/master/README.md

## 1.4 Permissionless reporting workflow

See the @witnet/price-feeds README:

- https://github.com/witnet/price-feeds/blob/master/README.md

## 1.5 Introspect sources and history via CLI

See the @witnet/price-feeds README:

- https://github.com/witnet/price-feeds/blob/master/README.md

## 2. Randomness

## 2.1 Pull from contracts

Use WitRandomness randomize flow from your contract and consume finalized randomness once available.

## 2.2 Pull from off-chain

```bash
npx witeth randomness --target <wit_randomness_address> --randomize --signer <evm_address>
npx randomizer --target <wit_randomness_address>
```

## 2.3 Callback consumer pattern

1. Clone WitRandomness.
2. Trigger randomize from bot or transactions.
3. Implement IWitRandomnessConsumer callback entrypoint.

```bash
npx witeth randomness --target <wit_randomness_address> --clone --signer <evm_address>
```

## 3. Custom Feeds (Radon Requests)

## 3.1 Radon Request model

A Radon Request defines data retrieval, transformation, aggregation, and commit/reveal parameters.

## 3.2 Build invariable and parameterized requests

- Solidity: framework artifacts and contracts.
- JavaScript: @witnet/sdk asset composition.

## 3.3 Dry-run and verification

```bash
npx witeth assets --all --decode
npx witeth assets <request_or_template> --dry-run
npx witeth assets <request_or_template> --deploy
```

## 3.4 Pull by RAD hash and validate pushed updates

```bash
npx witeth queries --filter-radHash <rad_hash_fragment>
npx witeth reports --filter-radHash <rad_hash_fragment> --parse
```
