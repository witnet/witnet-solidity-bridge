import type { Witnet } from "@witnet/sdk";
import { type Addressable, type BlockTag, Contract, type EventLog, JsonRpcProvider, type JsonRpcSigner } from "ethers";
import type { ContractRunner } from "ethers/providers";
import type { WitOracleQuery, WitOracleQueryParams, WitOracleQueryResponse, WitOracleQueryStatus } from "../types.js";
import { abiDecodeQueryStatus, abiEncodeWitOracleQueryParams, fetchEvmNetworkFromProvider } from "../utils.js";
import { WitArtifact } from "./WitArtifact.js";
import { WitOracleConsumer } from "./WitOracleConsumer.js";
import { WitOracleRadonRegistry } from "./WitOracleRadonRegistry.js";
import { WitOracleRadonRequestFactory } from "./WitOracleRadonRequestFactory.js";
import { WitPriceFeeds } from "./WitPriceFeeds.js";
import { WitPriceFeedsLegacy } from "./WitPriceFeedsLegacy.js";
import { WitRandomness } from "./WitRandomness.js";

/**
 * Wrapper class for the Wit/Oracle contract as deployed in some specified EVM network.
 * It provides wrappers to other main artifacts of the Wit/Oracle Framework, as well
 * as factory methods for wrapping existing `WitOracleRadonRequestTemplateFactory` and `WitOracleConsumer`
 * compliant contracts, provably bound to the Wit/Oracle core contract.
 *
 */
export class WitOracle extends WitArtifact {
	/**
	 * Factory method to create a `WitOracle` wrapper instance from an existing `JsonRpcProvider`.
	 * The provider must be connected to an EVM network where the Wit/Oracle Framework is deployed.
	 * @param provider An ethers.js `JsonRpcProvider` instance connected to an EVM network where the Wit/Oracle Framework is deployed.
	 * @returns A `WitOracle` wrapper instance connected to the same EVM network as the given provider.
	 */
	public static async fromEthRpcProvider(provider: JsonRpcProvider): Promise<WitOracle> {
		const network = await fetchEvmNetworkFromProvider(provider);
		if (!network) {
			throw new Error(`WitOracle: unsupported network at given JsonRpcProvider`);
		}
		return new WitOracle({ network: network.name, networkId: network.id, runner: provider });
	}

	/**
	 * Factory method to create a `WitOracle` wrapper instance from an existing `JsonRpcSigner`.
	 * The signer must be connected to an EVM network where the Wit/Oracle Framework is deployed.
	 * @param signer
	 * @returns
	 */
	public static async fromEthRpcSigner(signer: JsonRpcSigner): Promise<WitOracle> {
		const network = await fetchEvmNetworkFromProvider(signer.provider);
		if (!network) {
			throw new Error(`WitOracle: unsupported network at given JsonRpcSigner`);
		}
		return new WitOracle({ network: network.name, networkId: network.id, runner: signer });
	}

	/**
	 * Factory method to create a `WitOracle` wrapper instance from an Ethereum JSON-RPC URL.
	 * The URL must point to an EVM network where the Wit/Oracle Framework is deployed.
	 * @param url
	 * @returns
	 */
	public static async fromEthRpcUrl(url: string): Promise<WitOracle> {
		return WitOracle.fromEthRpcProvider(new JsonRpcProvider(url));
	}

	private constructor(specs: {
		network: string;
		networkId: number;
		runner: ContractRunner;
	}) {
		super({ ...specs, artifact: "WitOracle" });
	}

	public async estimateBaseFee(evmGasPrice: bigint): Promise<bigint> {
		return this.contract.getFunction("estimateBaseFee(uint256)").staticCall(evmGasPrice);
	}

	public async estimateBaseFeeWithCallback(evmGasPrice: bigint, evmCallbackGas: number): Promise<bigint> {
		return this.contract
			.getFunction("estimateBaseFeeWithCallback(uint256,uint24)")
			.staticCall(evmGasPrice, evmCallbackGas);
	}

	public async estimateExtraFee(
		evmGasPrice: bigint,
		evmWitPrice: bigint,
		queryParams: WitOracleQueryParams,
	): Promise<bigint> {
		return this.contract
			.getFunction("estimateExtraFee(uint256,uint256,(uint16,uint16,uint64)")
			.staticCall(evmGasPrice, evmWitPrice, abiEncodeWitOracleQueryParams(queryParams));
	}

	public async filterWitOracleQueryEvents(options: {
		fromBlock: BlockTag;
		toBlock?: BlockTag;
		where?: {
			evmRequester?: string;
			queryRadHash?: Witnet.Hash;
		};
	}): Promise<
		Array<{
			evmBlockNumber: bigint;
			evmRequester: string;
			evmTransactionHash: string;
			queryId: bigint;
			queryRadHash: Witnet.Hash;
			queryParams: WitOracleQueryParams;
		}>
	> {
		const witOracleQueryEvent = this.contract.filters[
			"WitOracleQuery(address indexed,uint256,uint256,uint64,bytes32,(uint16,uint16,uint64))"
		](options?.where?.evmRequester);
		return this.contract
			.queryFilter(witOracleQueryEvent, options.fromBlock, options?.toBlock)
			.then((logs) =>
				logs.filter(
					(log) =>
						!log.removed &&
						// && (!options?.where?.evmRequester || (log as EventLog).args?.requester === options.where.evmRequester)
						(!options?.where?.queryRadHash ||
							(log as EventLog).args?.radonHash.indexOf(options.where.queryRadHash) >= 0),
				),
			)
			.then((logs) =>
				logs.map((log) => ({
					evmBlockNumber: BigInt(log.blockNumber),
					evmRequester: (log as EventLog).args?.evmRequester as string,
					evmTransactionHash: log.transactionHash,
					queryId: BigInt((log as EventLog).args.queryId),
					queryRadHash: (log as EventLog).args.radonHash as Witnet.Hash,
					queryParams: {
						witnesses: (log as EventLog).args.radonParams[1] as number,
						unitaryReward: BigInt((log as EventLog).args.radonParams[2]),
						resultMaxSize: (log as EventLog).args.radonParams[0] as number,
					} as WitOracleQueryParams,
				})),
			);
	}

	public async filterWitOracleReportEvents(options: {
		fromBlock: BlockTag;
		toBlock?: BlockTag;
		where?: {
			evmOrigin?: string;
			evmConsumer?: string;
			queryRadHash?: Witnet.Hash;
		};
	}): Promise<
		Array<{
			evmBlockNumber: bigint;
			evmOrigin: string;
			evmConsumer: string;
			evmReporter: string;
			evmTransactionHash: string;
			witDrTxHash: Witnet.Hash;
			queryRadHash: Witnet.Hash;
			queryParams: WitOracleQueryParams;
			resultCborBytes: Witnet.HexString;
			resultTimestamp: number;
		}>
	> {
		const witOracleReportEvent = this.contract.filters.WitOracleReport(
			options?.where?.evmOrigin,
			options?.where?.evmConsumer,
		);
		return this.contract
			.queryFilter(witOracleReportEvent, options.fromBlock, options?.toBlock)
			.then((logs) =>
				logs.filter(
					(log) =>
						!log.removed &&
						(!options?.where?.queryRadHash ||
							(log as EventLog).args?.queryRadHash.indexOf(options.where.queryRadHash) >= 0),
				),
			)
			.then((logs) =>
				logs.map((log) => ({
					evmBlockNumber: BigInt(log.blockNumber),
					evmOrigin: (log as EventLog).args.evmOrigin,
					evmConsumer: (log as EventLog).args.evmConsumer,
					evmReporter: (log as EventLog).args.evmReporter,
					evmTransactionHash: log.transactionHash,
					witDrTxHash: (log as EventLog).args.witDrTxHash,
					queryRadHash: (log as EventLog).args.queryRadHash,
					queryParams: {
						witnesses: (log as EventLog).args.queryParams[1] as number,
						unitaryReward: BigInt((log as EventLog).args.queryParams[2]),
						resultMaxSize: (log as EventLog).args.queryParams[0] as number,
					},
					resultCborBytes: (log as EventLog).args.resultCborBytes,
					resultTimestamp: Number((log as EventLog).args.resultTimestamp),
				})),
			);
	}

	public async getEvmChainId(): Promise<number> {
		return this.provider.getNetwork().then((network) => Number(network.chainId));
	}

	public async getEvmChannel(): Promise<Witnet.HexString> {
		return this.contract.getFunction("channel()").staticCall();
	}

	public async getNextQueryId(): Promise<bigint> {
		return this.contract.getFunction("getNextQueryId()").staticCall();
	}

	public async getQuery(queryId: bigint): Promise<WitOracleQuery> {
		return this.contract.getQuery.staticCall(queryId).then((result) => ({
			checkpoint: BigInt(result[5]),
			hash: result[3],
			params: {
				resultMaxSize: result[2][0],
				unitaryReward: result[2][2],
				witnesses: result[2][1],
			},
			request: {
				callbackGas: Number(result[0][1]),
				radonHash: result[0][3],
				requester: result[0][0],
			},
			response: {
				disputer: result[1][4],
				reporter: result[1][0],
				resultTimestamp: Number(result[1][1].toString()),
				resultDrTxHash: result[1][2],
				resultCborBytes: result[1][3],
			},
		}));
	}

	public async getQueryResponse(queryId: bigint): Promise<WitOracleQueryResponse> {
		return this.contract.getQueryResponse.staticCall(queryId).then((result) => ({
			disputer: result[4],
			reporter: result[0],
			resultTimestamp: Number(result[1].toString()),
			resultDrTxHash: result[2],
			resultCborBytes: result[3],
		}));
	}

	public async getQueryResultStatusDescription(queryId: bigint): Promise<string> {
		let reason;
		try {
			try {
				reason = await this.contract.getQueryResultStatusDescription.staticCall(queryId);
			} catch {
				const legacy = new Contract(
					this.address,
					["function getQueryResultError(uint256) public view returns ((uint8,string))"],
					this.runner,
				);
				reason = await legacy.getQueryResultError.staticCall(queryId).then((result) => result[1]);
			}
		} catch {
			reason = "(unparsable error)";
		}
		return reason;
	}

	public async getQueryStatuses(queryIds: bigint[]): Promise<Array<WitOracleQueryStatus>> {
		return this.contract.getQueryStatusBatch
			.staticCall(queryIds)
			.then((statuses: Array<bigint>) => statuses.map((value) => abiDecodeQueryStatus(value)));
	}

	public async _getWitOracleConsumerAt(target: string): Promise<WitOracleConsumer> {
		return WitOracleConsumer.fromWitOracle(this, target);
	}

	/**
	 * Wrapper class for the Wit/Oracle Radon Registry core contract as deployed in some supported EVM network.
	 * It allows formal verification of Radon Requests and Witnet-compliant data sources into such network,
	 * as to be securely referred on both Wit/Oracle queries pulled from within smart contracts,
	 * or Wit/Oracle query results pushed into smart contracts from offchain workflows.
	 */
	public async _getWitOracleRadonRegistry(): Promise<WitOracleRadonRegistry> {
		return WitOracleRadonRegistry.fromWitOracle(this);
	}

	/**
	 * Wrapper class for the Wit/Oracle Request Factory core contract as deployed in some supported EVM network.
	 * It allows construction of `WitOracleRadonRequestTemplateFactory` minimal-proxy contracts out of one ore more
	 * parameterized Radon Retievals (Witnet-compliant data sources). Template addresses are counter-factual to
	 * the set of data sources they are built on.
	 */
	public async _getWitOracleRadonRequestFactory(at?: string | Addressable): Promise<WitOracleRadonRequestFactory> {
		return WitOracleRadonRequestFactory.fromWitOracle(this, at);
	}

	/**
	 * Wrapper class for the Wit/Price Feeds core contract as deployed in some supported EVM network.
	 * It allows formal verification of Witnet-compliant price feeds into such network,
	 * as to be securely referred on both Wit/Oracle queries pulled from within smart contracts,
	 * or Wit/Oracle query results pushed into smart contracts from offchain workflows.
	 * @param at The address of the Wit/Price Feeds contract to be wrapped, other than framework's default.
	 * @returns A `WitPriceFeeds` instance wrapping the specified contract.
	 */
	public async _getWitPriceFeeds(at?: string | Addressable): Promise<WitPriceFeeds> {
		return WitPriceFeeds.fromWitOracle(this, at);
	}

	/**
	 * Wrapper class for the legacy Wit/Price Feeds core contract as deployed in some supported EVM network.
	 * It allows formal verification of legacy Witnet-compliant price feeds into such network,
	 * as to be securely referred on both Wit/Oracle queries pulled from within smart contracts,
	 * or Wit/Oracle query results pushed into smart contracts from offchain workflows.
	 * @param at The address of the legacy Wit/Price Feeds contract to be wrapped, other than framework's default.
	 * @returns A `WitPriceFeedsLegacy` instance wrapping the specified contract.
	 * Note: this contract is deprecated and should only be used for backwards compatibility with existing deployments.
	 */
	public async _getWitPriceFeedsLegacy(at?: string | Addressable): Promise<WitPriceFeedsLegacy> {
		return WitPriceFeedsLegacy.fromWitOracle(this, at);
	}

	/**
	 * Wrapper class for the Wit/Randomness core contract as deployed in some supported EVM network.
	 * It allows formal verification of Witnet-compliant randomness requests into such network,
	 * as to be securely referred on both Wit/Oracle queries pulled from within smart contracts,
	 * or Wit/Oracle query results pushed into smart contracts from offchain workflows.
	 * @param at The address of the Wit/Randomness contract to be wrapped, other than framework's default.
	 * @returns A `WitRandomness` instance wrapping the specified contract.
	 */
	public async _getWitRandomness(at?: string | Addressable): Promise<WitRandomness> {
		return WitRandomness.fromWitOracle(this, at);
	}
}
