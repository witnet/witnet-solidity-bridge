import type { Witnet } from "@witnet/sdk";
import {
	AbiCoder,
	type Addressable,
	type BlockTag,
	Contract,
	type ContractTransaction,
	type ContractTransactionReceipt,
	type EventLog,
	type TransactionReceipt,
} from "ethers";
import { ABIs } from "../../index.js";
import type { RandomizeStatus } from "../types.js";

import { WitAppliance } from "./WitAppliance.js";
import type { WitOracle } from "./WitOracle.js";

export class WitRandomness extends WitAppliance {
	public static async fromWitOracle(witOracle: WitOracle, target?: string | Addressable): Promise<WitRandomness> {
		const randomness = new WitRandomness({ witOracle, target });
		let randomnessWitOracleAddr;
		try {
			randomnessWitOracleAddr = await randomness.provider
				.call({
					to: target,
					data: "0x46d1d21a", // funcSig for 'witnet()'
				})
				.then((result) => AbiCoder.defaultAbiCoder().decode(["address"], result))
				.then((result) => result.toString());
		} catch (_error) {
			randomnessWitOracleAddr = await randomness.contract.witOracle.staticCall();
		}
		if (randomnessWitOracleAddr !== witOracle.address) {
			throw new Error(
				`${WitRandomness.constructor.name} at ${target}: mismatching Wit/Oracle address (${randomnessWitOracleAddr})`,
			);
		} else {
			return randomness;
		}
	}

	protected constructor(specs: {
		witOracle: WitOracle;
		target?: string | Addressable;
	}) {
		super({ ...specs, artifact: "WitRandomnessV3" });
		this._legacy = new Contract(this.address, ABIs.WitRandomnessV2, this.runner);
	}

	/**
	 * The underlying Ethers' contract wrapper for the V2 implementation, used for event filtering and backward compatibility with V2 methods.
	 */
	protected _legacy: Contract;

	public async clone(
		curator: string,
		options?: {
			evmConfirmations?: number;
			evmGasPrice?: bigint;
			evmTimeout?: number;
			onTransaction?: (TxHash: Witnet.Hash) => any;
			onTransactionReceipt?: (receipt: TransactionReceipt | null) => any;
		},
	): Promise<ContractTransactionReceipt | TransactionReceipt | null> {
		const tx: ContractTransaction = await this.contract.clone.populateTransaction(curator);
		tx.gasPrice = options?.evmGasPrice || tx?.gasPrice;
		return this._checkSigner()
			.sendTransaction(tx)
			.then((response) => {
				if (options?.onTransaction) {
					options.onTransaction(response.hash);
				}
				return response.wait(options?.evmConfirmations || 1, options?.evmTimeout);
			})
			.then((receipt) => {
				if (options?.onTransactionReceipt) {
					options.onTransactionReceipt(receipt);
				}
				return receipt;
			});
	}

	public async estimateRandomizeFee(evmGasPrice: bigint): Promise<bigint> {
		return this.contract.getFunction("estimateRandomizeFee(uint256)").staticCall(evmGasPrice);
	}

	public async fetchRandomnessAfter(evmBlockNumber: bigint): Promise<Witnet.HexString | undefined> {
		return this.isRandomized(evmBlockNumber).then((isRandomized) => {
			return isRandomized ? this.contract.fetchRandomnessAfter.staticCall(evmBlockNumber) : undefined;
		});
	}

	public async fetchRandomnessAfterProof(evmBlockNumber: bigint): Promise<{
		finality: bigint;
		timestamp: number;
		trail: Witnet.Hash;
		uuid: Witnet.Hash;
	}> {
		return this.contract.fetchRandomnessAfterProof.staticCall(evmBlockNumber).then((result) => ({
			finality: BigInt(result[3]),
			timestamp: Number(result[1]),
			trail: result[2],
			uuid: result[0],
		}));
	}

	public async filterEvents(options: { fromBlock: BlockTag; toBlock?: BlockTag }): Promise<
		Array<{
			queryId: bigint;
			randomizeBlock: bigint;
			requester?: string;
			transactionHash: string;
		}>
	> {
		const logs = await this._legacy.queryFilter("Randomizing", options.fromBlock, options?.toBlock);
		if (logs && logs.length > 0) {
			return logs
				.filter((log) => !log.removed)
				.map((log) => ({
					queryId: (log as EventLog)?.args[3],
					randomizeBlock: (log as EventLog)?.args[0],
					transactionHash: log.transactionHash,
				}));
		} else {
			return this.contract
				.queryFilter("Randomizing", options.fromBlock, options?.toBlock)
				.then((logs) => logs.filter((log) => !log.removed))
				.then((logs) =>
					logs.map((log) => ({
						queryId: (log as EventLog)?.args[2],
						randomizeBlock: (log as EventLog)?.args[1],
						requester: (log as EventLog)?.args[0],
						transactionHash: log.transactionHash,
					})),
				);
		}
	}

	public async getEvmBase(): Promise<string> {
		return this.contract.base.staticCall().catch((_) => {
			return this._address;
		});
	}

	public async getEvmConsumer(): Promise<Witnet.HexString> {
		return this.contract.consumer.staticCall().catch((_) => {
			return this._address;
		});
	}

	public async getEvmCurator(): Promise<Witnet.HexString> {
		return this.contract.owner.staticCall();
	}

	public async getSettings(): Promise<{
		callbackGasLimit: number;
		extraFeePercentage: number;
		randomizeWaitBlocks: number;
		witCommitteeSize: number;
		witInclusionFees: bigint;
	}> {
		const [queryParams, waitingBlocks] = await Promise.all([
			this.contract.getRandomizeQueryParams(),
			this.contract.getRandomizeWaitingBlocks(),
		]);
		return {
			callbackGasLimit: Number(queryParams[0]),
			extraFeePercentage: Number(queryParams[1]),
			randomizeWaitBlocks: Number(waitingBlocks),
			witCommitteeSize: Number(queryParams[2]),
			witInclusionFees: BigInt(queryParams[3]),
		};
	}

	public async getLastRandomizeBlock(): Promise<bigint> {
		return this.contract.getFunction("getLastRandomizeBlock()").staticCall();
	}

	public async getRandomizeStatus(evmBlockNumber: bigint): Promise<RandomizeStatus> {
		return this.contract.getRandomizeStatus.staticCall(evmBlockNumber).then((result) => {
			switch (Number(result)) {
				case 1:
					return "Awaiting";
				case 2:
					return "Ready";
				case 3:
					return "Error";
				case 4:
					return "Finalizing";
			}
			return "Void";
		});
	}

	public async isRandomized(evmBlockNumber: bigint): Promise<boolean> {
		return this.contract.isRandomized.staticCall(evmBlockNumber);
	}

	public async randomize(options?: {
		evmConfirmations?: number;
		evmGasPrice?: bigint;
		evmTimeout?: number;
		onRandomizeTransaction?: (txHash: Witnet.Hash) => any;
		onRandomizeTransactionReceipt?: (receipt: TransactionReceipt | null) => any;
	}): Promise<ContractTransactionReceipt | TransactionReceipt | null> {
		const evmGasPrice = options?.evmGasPrice || (await this.provider.getFeeData()).gasPrice || 0n;
		const evmRandomizeFee = await this.estimateRandomizeFee(evmGasPrice);
		const evmTransaction: ContractTransaction = await this.contract.getFunction("randomize()").populateTransaction();
		evmTransaction.gasPrice = evmGasPrice || evmTransaction?.gasPrice;
		evmTransaction.value = evmRandomizeFee;
		return this._checkSigner()
			.sendTransaction(evmTransaction)
			.then((response) => {
				if (options?.onRandomizeTransaction) options.onRandomizeTransaction(response.hash);
				return response.wait(options?.evmConfirmations || 1, options?.evmTimeout);
			})
			.then((receipt) => {
				if (options?.onRandomizeTransactionReceipt) options.onRandomizeTransactionReceipt(receipt);
				return receipt;
			});
	}
}
