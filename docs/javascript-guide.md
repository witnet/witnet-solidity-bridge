# JavaScript Developer Guide

This guide explains utilities and wrappers exposed by @witnet/solidity.

## 1. Utilities

Main utilities exported from @witnet/solidity/utils include:

- fetchWitOracleFramework
- fetchEvmNetworkFromProvider
- getEvmNetworkByChainId
- getEvmNetworkAddresses
- getEvmNetworks
- abiDecodeQueryStatus
- abiEncodeDataPushReport
- abiEncodeDataPushReportMessage
- abiEncodeDataPushReportDigest
- abiEncodePriceFeedUpdateConditions
- abiEncodeWitOracleQueryParams
- abiEncodeRadonAsset

## 2. Instantiate wrappers from ethers JsonRpcProvider

```ts
import { ethers, utils, WitOracle } from "@witnet/solidity";

const provider = new ethers.JsonRpcProvider(process.env.ETH_RPC_URL!);

const network = await utils.fetchEvmNetworkFromProvider(provider);
console.log(network);

const framework = await utils.fetchWitOracleFramework(provider);
console.log(Object.keys(framework));

const witOracle = await WitOracle.fromEthRpcProvider(provider);
const priceFeeds = await witOracle._getWitPriceFeeds();
const randomness = await witOracle._getWitRandomness();

console.log(priceFeeds.address, randomness.address);
```

## 3. Radon workflows from JS plus CLI validation

1. Build invariable and parameterized Radon assets with @witnet/sdk.
2. Use CLI to decode and dry-run before deployment.
3. Use CLI trace-back options to inspect data sources and witness trails.

```bash
npx witeth assets --all --decode
npx witeth assets <assetName> --dry-run
npx witeth priceFeeds --trace-back
npx witeth queries --trace-back --limit 20
```
