import type { Witnet } from "@witnet/sdk";
import type { ContractWrapper } from "./wrappers/ContractWrapper.js";

export type DataPushReport = Witnet.DataPushReport;

export type PriceFeed = {
	id?: string;
	id4: string;
	exponent: number;
	symbol: string;
	mapper?: PriceFeedMapper;
	oracle?: PriceFeedOracle;
	updateConditions?: PriceFeedUpdateConditions;
	lastUpdate?: PriceFeedUpdate;
};

export type PriceFeedMapper = {
	class: string;
	deps: Array<string>;
};

export enum PriceFeedMappers {
	None,
	Fallback,
	Hottest,
	Product,
	Inverse,
}

export type PriceFeedOracle = {
	class: string;
	target: string;
	sources: Witnet.Hash;
};

export enum PriceFeedOracles {
	Witnet,
	Erc2362,
	Chainlink,
	Pyth,
	// Redstone,
}

export type PriceFeedUpdate = {
	price: number;
	deltaPrice?: number;
	exponent?: number;
	timestamp: number;
	trail: Witnet.Hash;
};

export type PriceFeedUpdateConditions = {
	callbackGas: number;
	computeEMA: boolean;
	cooldownSecs: number;
	heartbeatSecs: number;
	maxDeviationPercentage: number;
	minWitnesses: number;
};

export type RandomizeStatus = "Void" | "Awaiting" | "Finalizing" | "Ready" | "Error";
export { TransactionReceipt } from "ethers";

export type WitOracleArtifact = {
	address: Witnet.HexString;
	abi: any;
	class: string;
	gitHash?: string;
	interfaceId: Witnet.HexString;
	isUpgradable: boolean;
	semVer?: string;
	version?: string;
	wrapper?: ContractWrapper;
};

export type WitOracleQuery = {
	checkpoint: bigint;
	hash: Witnet.Hash;
	params: WitOracleQueryParams;
	request: WitOracleQueryRequest;
	response?: WitOracleQueryResponse;
};

export type WitOracleQueryParams = {
	/**
	 * Maximum expected size of the CBOR-encoded query result, once solved by the Witnet blockchain.
	 */
	resultMaxSize?: number;
	/**
	 * Mininum reward in $nanoWIT for very validator that positively contributes to get the Wit/Oracle
	 * query attended, solved and stored into the Witnet blockchain.
	 */
	unitaryReward: bigint;
	/**
	 * Maximum number of witnessing nodes required to participate in solving the oracle query.
	 */
	witnesses: number;
};

export type WitOracleQueryRequest = {
	callbackGas?: number;
	radonHash: Witnet.Hash;
	requester: string;
};

export type WitOracleQueryResponse = {
	disputer?: string;
	reporter?: string;
	resultTimestamp?: number;
	resultDrTxHash: Witnet.Hash;
	resultCborBytes: Witnet.HexString;
};

export type WitOracleQueryStatus = "Void" | "Posted" | "Reported" | "Finalized" | "Delayed" | "Expired" | "Disputed";
export type WitOracleResultDataTypes = "any" | "array" | "boolean" | "bytes" | "float" | "integer" | "map" | "string";
