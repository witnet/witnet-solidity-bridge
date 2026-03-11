import { Witnet } from "@witnet/sdk";

import { default as cbor } from "cbor";

import {
	AbiCoder,
	Contract,
	isAddress,
	type JsonRpcApiProvider,
	type JsonRpcProvider,
	solidityPackedKeccak256,
} from "ethers";
import { default as merge } from "lodash.merge";
import { default as helpers } from "../bin/helpers.cjs";
import { ABIs } from "../index.js";

import type {
	PriceFeedUpdateConditions,
	WitOracleArtifact,
	WitOracleQueryParams,
	WitOracleQueryStatus,
} from "./types.js";
import { WitOracle } from "./wrappers.js";

export * from "@witnet/sdk/utils";

export function getNetworkTagsFromString(network: string) {
	return helpers.getNetworkTagsFromString(network);
}

export async function fetchWitOracleFramework(
	provider: JsonRpcProvider,
): Promise<{ [key: string]: WitOracleArtifact }> {
	return provider.getNetwork().then(async (value) => {
		const network = getEvmNetworkByChainId(Number(value.chainId));
		if (network) {
			const exclusions = ["WitOracleRadonRequestFactoryModals", "WitOracleRadonRequestFactoryTemplates"];
			const targets = [
				"WitOracle",
				"WitOracleRadonRegistry",
				"WitOracleRadonRequestFactory",
				"WitPriceFeeds",
				"WitPriceFeedsLegacy",
				"WitRandomnessV2",
				"WitRandomnessV3",
			];
			const contracts = Object.fromEntries(
				Object.entries(helpers.flattenObject(helpers.getNetworkArtifacts(network))).map(([key, value]) => [
					key.split(".").pop(),
					value,
				]),
			);
			let { addresses } = helpers.readWitnetJsonFiles("addresses");
			addresses = merge(helpers.getNetworkAddresses(network), addresses[network]);
			return await Promise.all(
				Object.entries(helpers.flattenObject(addresses))
					.map(([key, address]) => [key.split(".").pop(), address])
					.sort(([a], [b]) => (a as string).localeCompare(b))
					.filter(([key, address]) => {
						const base = _findBase(contracts, key);
						return (
							address &&
							address !== "0x0000000000000000000000000000000000000000" &&
							targets.includes(key) &&
							!exclusions.includes(base) &&
							(ABIs[key] || ABIs[base])
						);
					})
					.map(async ([key, address]) => {
						const bytecode = await provider.getCode(address).catch((err) => {
							console.error(`Warning: ${key}: ${err}`);
							return undefined;
						});
						if (!bytecode?.length || bytecode.length <= 2) {
							return [key, undefined];
						}

						const appliance = new Contract(address, ABIs.WitAppliance, provider);
						const upgradable = new Contract(address, ABIs.WitnetUpgradableBase, provider);

						// Execute all contract calls in parallel for better performance
						const [impl, interfaceId, isUpgradable, version] = await Promise.allSettled([
							appliance.class.staticCall(),
							appliance.specs.staticCall(),
							upgradable.isUpgradable.staticCall(),
							upgradable.version.staticCall(),
						]).then((results) => [
							(results[0].status === "fulfilled" ? results[0].value : key) as string,
							(results[1].status === "fulfilled" ? results[1].value : undefined) as string | undefined,
							(results[2].status === "fulfilled" ? results[2].value : false) as boolean,
							(results[3].status === "fulfilled" ? results[3].value : undefined) as string | undefined,
						]);

						return [
							key,
							{
								abi: ABIs[key] || (typeof impl === "string" ? ABIs[impl] : undefined),
								address,
								class: impl,
								gitHash: _versionLastCommitOf(version?.toString()),
								interfaceId,
								isUpgradable,
								semVer: _versionTagOf(version?.toString()),
								version,
							} as WitOracleArtifact,
						];
					}),
			)
				.then((artifacts) => artifacts.filter(([, artifact]) => artifact !== undefined))
				.then(async (artifacts) => {
					const artifactMap = Object.fromEntries(artifacts);
					if (artifactMap.WitOracle) {
						const witOracle = await WitOracle.fromEthRpcProvider(provider);
						artifacts = await Promise.all(
							artifacts.map(async ([key, artifact]) => {
								let wrapper: any;
								switch (key) {
									case "WitOracle":
										wrapper = witOracle;
										break;
									case "WitOracleRadonRegistry":
										wrapper = await witOracle._getWitOracleRadonRegistry().catch((err) => {
											console.error("Error getting WitOracleRadonRegistry wrapper:", err);
											return undefined;
										});
										break;
									case "WitOracleRadonRequestFactory":
										wrapper = await witOracle._getWitOracleRadonRequestFactory().catch((err) => {
											console.error("Error getting WitOracleRadonRequestFactory wrapper:", err);
											return undefined;
										});
										break;
									case "WitPriceFeeds":
										wrapper = await witOracle._getWitPriceFeeds(artifact.address).catch((err) => {
											console.error("Error getting WitPriceFeeds wrapper:", err);
											return undefined;
										});
										break;
									case "WitPriceFeedsLegacy":
										wrapper = await witOracle._getWitPriceFeedsLegacy(artifact.address).catch((err) => {
											console.error("Error getting WitPriceFeedsLegacy wrapper:", err);
											return undefined;
										});
										break;
									default:
										if (key.startsWith("WitRandomness") || key.startsWith("WitnetRandomness")) {
											wrapper = await witOracle._getWitRandomness(artifact.address).catch((err) => {
												console.error(`Error getting ${key} wrapper:`, err);
												return undefined;
											});
										}
								}
								return [key, wrapper ? { ...artifact, wrapper } : artifact];
							}),
						);
					}
					return Object.fromEntries(artifacts);
				});
		} else {
			return {};
		}
	});
}

function _findBase(obj: { [k: string]: any }, value: string): string {
	return Object.entries(obj).find(([, impl]) => impl === value)?.[0] || "";
}
function _versionTagOf(version?: string) {
	return version?.slice(0, 5);
}
function _versionLastCommitOf(version?: string) {
	if (version) {
		return version?.length >= 21 ? version?.slice(-15, -8) : "";
	} else {
		return undefined;
	}
}

export async function fetchEvmNetworkFromProvider(
	provider: JsonRpcApiProvider,
): Promise<{ name: string; id: number } | undefined> {
	return provider.getNetwork().then((value) => {
		const network = getEvmNetworkByChainId(Number(value.chainId));
		if (network) {
			return { name: network, id: Number(value.chainId) };
		} else {
			return undefined;
		}
	});
}

export function getEvmNetworkAddresses(network: string): any {
	return helpers.getNetworkAddresses(network);
}

export function getEvmNetworkByChainId(chainId: number): string | undefined {
	const found = Object.entries(helpers.supportedNetworks()).find(
		([, config]: [string, any]) => config?.network_id.toString() === chainId.toString(),
	);
	if (found) return found[0];
	else return undefined;
}

export function getEvmNetworkId(network: string): number | undefined {
	const found = Object.entries(helpers.supportedNetworks()).find(
		([key]: [string, any]) => network && key.toLowerCase() === network.toLowerCase(),
	);
	if (found) return (found[1] as any)?.network_id;
	else return undefined;
}

export function getEvmNetworkSymbol(network: string): string {
	const found = Object.entries(helpers.supportedNetworks()).find(
		([key]: [string, any]) => network && key.toLowerCase() === network.toLowerCase(),
	);
	if (found) return (found[1] as any)?.symbol;
	else return "ETH";
}

export function getEvmNetworks(): {
	[key: string]: {
		name: string;
		chainId: number;
		ecosystem: string;
		mainnet: boolean;
		port: number;
		pushOnly: boolean;
		symbol: string;
		addresses?: any;
	};
} {
	return helpers.supportedNetworks();
}

export function isEvmNetworkMainnet(network: string): boolean {
	const found = Object.entries(helpers.supportedNetworks()).find(([key]) => network && key === network.toLowerCase());
	return (found as any)?.[1].mainnet;
}

export function isEvmNetworkSupported(network: string): boolean {
	return helpers.supportsNetwork(network);
}

export function isValidEvmAddress(address?: string): boolean {
	return (
		address !== undefined &&
		address !== "0x0000000000000000000000000000000000000000" &&
		/^0x[0-9a-fA-F]{40}$/.test(address) &&
		isAddress(address)
	);
}

export function abiDecodeQueryStatus(status: bigint): WitOracleQueryStatus {
	switch (status) {
		case 1n:
			return "Posted";
		case 2n:
			return "Reported";
		case 3n:
			return "Finalized";
		case 4n:
			return "Delayed";
		case 5n:
			return "Expired";
		case 6n:
			return "Disputed";
		default:
			return "Void";
	}
}

/**
 * Contains information about the resolution of some Data Request Transaction in the Witnet blockchain.
 */
type _DataPushReportSolidity = {
	/**
	 * Unique hash of the Data Request Transaction that produced the outcoming result.
	 */
	drTxHash: Witnet.Hash;
	/**
	 * RAD hash of the Radon Request being solved.
	 */
	queryRadHash: Witnet.Hash;
	/**
	 * SLA parameters required to be fulfilled by the Witnet blockchain.
	 */
	queryParams: WitOracleQueryParams;
	/**
	 * Timestamp when the data sources where queried and the contained result produced.
	 */
	resultTimestamp: number;
	/**
	 * CBOR-encoded buffer containing the actual result data to some query as solved by the Witnet blockchain.
	 */
	resultCborBytes: Witnet.HexString;
};

function _intoDataPushReportSolidity(report: Witnet.DataPushReport): _DataPushReportSolidity {
	return {
		drTxHash: `0x${report.hash}`,
		queryParams: {
			witnesses: report.query?.witnesses || 0,
			unitaryReward: report.query?.unitary_reward || 0n,
			resultMaxSize: 0,
		},
		queryRadHash: `0x${report.query?.rad_hash}`,
		resultCborBytes: `0x${report.result?.cbor_bytes}`,
		resultTimestamp: report.result?.timestamp || 0,
	};
}

export function abiEncodeDataPushReport(report: Witnet.DataPushReport): any {
	const internal = _intoDataPushReportSolidity(report);
	return [
		internal.drTxHash,
		internal.queryRadHash,
		abiEncodeWitOracleQueryParams(internal.queryParams),
		internal.resultTimestamp,
		internal.resultCborBytes,
	];
}

export function abiEncodeDataPushReportMessage(report: Witnet.DataPushReport): Witnet.HexString {
	return AbiCoder.defaultAbiCoder().encode(
		["bytes32", "bytes32", "(uint16, uint16, uint64)", "uint64", "bytes"],
		abiEncodeDataPushReport(report),
	);
}

export function abiEncodeDataPushReportDigest(report: Witnet.DataPushReport): Witnet.HexString {
	return solidityPackedKeccak256(["bytes"], [abiEncodeDataPushReportMessage(report)]);
}

export function abiEncodePriceFeedUpdateConditions(conditions: PriceFeedUpdateConditions): any {
	return [
		conditions.callbackGas,
		conditions.computeEMA,
		conditions.cooldownSecs,
		conditions.heartbeatSecs,
		Math.floor(conditions.maxDeviationPercentage * 10),
		conditions.minWitnesses,
	];
}

export function abiEncodeWitOracleQueryParams(queryParams: WitOracleQueryParams): any {
	return [queryParams?.resultMaxSize || 0, queryParams?.witnesses || 0, queryParams?.unitaryReward || 0];
}
export function abiEncodeRadonAsset(asset: any): any {
	if (asset instanceof Witnet.Radon.RadonRetrieval) {
		return [
			asset.url || "",
			[
				asset.method,
				asset.body || "",
				asset?.headers ? Object.entries(asset.headers) : [],
				abiEncodeRadonAsset(asset.script) || "0x80",
			],
		];
	} else if (asset instanceof Witnet.Radon.types.RadonScript) {
		return asset.toBytecode();
	} else if (asset instanceof Witnet.Radon.reducers.Class) {
		return [asset.opcode, asset.filters?.map((filter) => abiEncodeRadonAsset(filter)) || []];
	} else if (asset instanceof Witnet.Radon.filters.Class) {
		return [asset.opcode, `0x${asset.args ? cbor.encode(asset.args).toString("hex") : ""}`];
	} else {
		throw new TypeError(`Not a Radon asset: ${asset}`);
	}
}
