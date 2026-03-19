# Operator Guide

This guide is for maintainers deploying, upgrading, and operating the Wit/Oracle Framework on EVM networks.

## 1. Configuration Surfaces

- Network metadata: chain ids, fee token info, explorer endpoints.
- Artifact mapping: implementation selection per base, ecosystem, and chain.
- Deployment specs: mutables, immutables, dependencies, libs, and vanity.

## 2. Fine-Tuning Implementations Per Network

### Decision checklist

1. Does the network require a special WitOracle implementation.
2. Does the network require custom request factory, registry, or deployer.
3. Do mutables or immutables need chain-specific values.
4. Are external library links compatible with this chain.

### Typical override strategy

1. Keep default mapping stable.
2. Apply ecosystem-level override when many chains share runtime constraints.
3. Apply chain-level override only for strict exceptions.

## 3. Upgrade Existing Supported Network

## 3.1 Preconditions

```bash
pnpm run fmt
pnpm run compile
```

## 3.2 Selective upgrade

Use your internal release workflow to upgrade only the targeted artifacts.

## 3.3 Full upgrade path

Use your approved full-upgrade process only when a selective upgrade is not sufficient.

## 3.4 Validation

```bash
npx witeth gateway <ecosystem:chain>
npx witeth framework --verbose
```

## 4. Add A New Network And Deploy

1. Add network metadata to your supported-network catalog.
2. Add implementation mapping overrides if needed.
3. Add deployment specs.
4. Deploy with your approved automation.
5. Validate framework state from CLI.

## 5. Operations Runbook

- Health checks: framework, priceFeeds, queries, randomness, reports.
- Credential hygiene: isolated signer keys per environment.
- Incident handling: capture tx hash, block, and failing artifact version before retries.
