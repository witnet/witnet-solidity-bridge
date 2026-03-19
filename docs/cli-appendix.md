# CLI Appendix

Command-by-command examples for Wit/Oracle operators and integrators.

## Global Notes

- Most commands expect a local ETH/RPC signing gateway at http://127.0.0.1:8545.
- Start gateway first when running network-bound commands.
- Use --help per command for full usage.

## 1. networks

Purpose: list supported EVM networks and their oracle model.

Examples:

```bash
npx witeth networks
npx witeth networks --mainnets
npx witeth networks --testnets
```

Typical output shape:

- table with Network, Fee Token, Network Id, Oracle Model, Explorer URL
- final summary line with number of listed networks

Common failures:

- no matching rows when over-filtering with --mainnets or --testnets

## 2. gateway

Purpose: launch local signing gateway bound to a supported network.

Examples:

```bash
npx witeth gateway ethereum:mainnet
npx witeth gateway base:sepolia --port 8546
npx witeth gateway polygon:mainnet --remote https://your.rpc.url
```

Typical output shape:

- gateway startup logs and provider connection messages

Common failures:

- Unsupported network when network key is not in settings
- provider connectivity or auth issues when using --remote

## 3. accounts

Purpose: show signer addresses exposed by gateway and their balances.

Examples:

```bash
npx witeth accounts
npx witeth accounts --port 8546
```

Typical output shape:

- table with index, signer address, and native token balance
- total balance row at the end

Common failures:

- gateway not reachable at selected port

## 4. framework

Purpose: inspect deployed framework artifacts on current chain.

Examples:

```bash
npx witeth framework
npx witeth framework --verbose
npx witeth framework WitOracle WitPriceFeeds
npx witeth framework --templates
npx witeth framework --modals
```

Typical output shape:

- table with artifact name, contract address, interface id
- with --verbose includes implementation class and version tag

Common failures:

- unsupported chain id if gateway is connected to an unmapped chain
- empty output when there are no deployed artifacts for that network

## 5. assets

Purpose: inspect, dry-run, decode, verify, and deploy Radon assets.

Examples:

```bash
npx witeth assets --all
npx witeth assets <assetName> --dry-run
npx witeth assets <assetName> --decode
npx witeth assets <assetName> --deploy --signer <evm_address>
npx witeth assets --module <npm_package> --all
```

Typical output shape:

- tree-like selection of discovered assets
- deployment or verification progress logs per retrieval/request/template
- gas usage summary for on-chain operations

Common failures:

- No Radon assets declared when module or local assets are missing
- transaction reverts during verify/deploy due to permissions or invalid inputs
- missing signer permissions when --deploy is used

## 6. priceFeeds

Purpose: show latest feed values and freshness for a price feed contract.

Examples:

```bash
npx witeth priceFeeds
npx witeth priceFeeds --target <wit_pricefeeds_address>
npx witeth priceFeeds --trace-back
```

Typical output shape:

- contract headline with class, address, version
- table with feed id, caption, last price, freshness
- last column shows providers or witness trail with --trace-back

Common failures:

- target contract not compatible with expected interface
- empty list when no feeds are configured on target

## 7. queries

Purpose: list WitOracle query events pulled from smart contracts.

Examples:

```bash
npx witeth queries --limit 20
npx witeth queries --since 0 --limit 50
npx witeth queries --filter-radHash <rad_hash_fragment>
npx witeth queries --filter-requester <evm_address>
npx witeth queries --trace-back
npx witeth queries --voids
```

Typical output shape:

- table with query id, requester, cost, rad hash fragment, status
- with --trace-back, table includes Witnet resolution tx hash

Common failures:

- no events in selected block window
- invalid address in --filter-requester

## 8. randomness

Purpose: list randomness requests, request new randomize, or clone contract.

Examples:

```bash
npx witeth randomness
npx witeth randomness --target <wit_randomness_address> --randomize --signer <evm_address>
npx witeth randomness --target <wit_randomness_address> --clone --signer <evm_address>
npx witeth randomness --trace-back
```

Typical output shape:

- contract headline with class, address, version
- request table with block, requester, gas, cost, TTR, status
- with --trace-back includes witness trail and finalized randomness

Common failures:

- signer has insufficient balance to pay fees
- randomize transaction rejected due to gas price or permissions
- target is not a valid WitRandomness contract

## 9. reports

Purpose: inspect pushed reports and push finalized Witnet reports to consumers.

Examples:

```bash
npx witeth reports --limit 20
npx witeth reports --parse
npx witeth reports --filter-consumer <evm_address>
npx witeth reports --filter-radHash <rad_hash_fragment>
npx witeth reports --push <wit_dr_tx_hash> --into <consumer_address> --signer <evm_address>
npx witeth reports --trace-back
```

Typical output shape:

- table with block, requester, consumer, cost, and reported bytes/data
- with --trace-back includes Witnet witnessing tx hash and time-to-report
- push flow prints digest and proof before sending transaction

Common failures:

- invalid WIT_DR_TX_HASH format
- missing --into when using --push
- consumer contract rejects pushed report

## 10. randomizer bot

Purpose: schedule and automate randomize requests from off-chain.

Examples:

```bash
npx randomizer --target <wit_randomness_address>
npx randomizer --target <wit_randomness_address> --network base:mainnet --schedule "*/10 * * * *"
npx randomizer --target <wit_randomness_address> --max-gas-price 2 --min-balance 0.05
```

Typical output shape:

- startup info with network, target, signer, schedule
- randomize tx details and post-confirmation witness/finality data
- periodic balance checks

Common failures:

- connected to wrong network when --network does not match gateway chain
- invalid cron expression in --schedule
- low signer balance under --min-balance
- high gas price above --max-gas-price causing postponement

## Troubleshooting Patterns

- If command says unsupported chain id, confirm gateway chain and supported-network configuration.
- If command finds no artifacts, verify the active network has deployed framework addresses configured.
- If PowerShell blocks npm scripts due to execution policy, run npm.cmd or npx.cmd equivalents.
