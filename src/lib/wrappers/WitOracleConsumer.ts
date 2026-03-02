import type { ContractTransactionReceipt, TransactionReceipt } from "ethers";
import type { DataPushReport } from "../types.js";
import { abiEncodeDataPushReport } from "../utils.js";
import { WitAppliance } from "./WitAppliance.js";
import type { WitOracle } from "./WitOracle.js";
import { Addressable } from "ethers";

export class WitOracleConsumer extends WitAppliance {

	public static async fromWitOracle(witOracle: WitOracle, target: string | Addressable): Promise<WitOracleConsumer> {
		const consumer = new WitOracleConsumer({ target, witOracle });
		const consumerWitOracleAddr = await consumer.contract.witOracle.staticCall();
		if (consumerWitOracleAddr !== witOracle.address) {
			throw new Error(
				`${WitOracleConsumer.constructor.name}: contract at ${target} not bound to the specified WitOracle at ${witOracle.address} in EVM network ${witOracle.network}.`
			);
		}
		return consumer;
	}

	protected constructor(specs: {
		target: string | Addressable,
		witOracle: WitOracle
	}) {
		super({ ...specs, artifact: "WitOracleConsumer" })
	}

	public async pushDataReport(
		report: DataPushReport,
		options?: {
			confirmations?: number;
			gasPrice?: bigint;
			gasLimit?: number;
			onDataPushReportTransaction?: (txHash: string) => any;
			timeout?: number;
		},
	): Promise<ContractTransactionReceipt | TransactionReceipt | null> {
		const signer = this._checkSigner();
		return this.contract
			.pushDataReport
			.populateTransaction(abiEncodeDataPushReport(report), report?.evm_proof)
			.then((tx) => {
				tx.gasPrice = options?.gasPrice || tx?.gasPrice;
				tx.gasLimit = options?.gasLimit ? BigInt(options.gasLimit) : tx?.gasLimit;
				return signer.sendTransaction(tx);
			})
			.then((response) => {
				if (options?.onDataPushReportTransaction) options.onDataPushReportTransaction(response.hash);
				return response.wait(options?.confirmations || 1, options?.timeout);
			});
	}
}
