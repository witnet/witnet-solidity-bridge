import { 
    formatUnits,
    AbiCoder,
    ContractTransaction, 
    ContractTransactionReceipt, 
    TransactionReceipt,
} from "ethers"

import { Witnet } from "@witnet/sdk"
import { abiEncodeDataPushReport, abiEncodePriceFeedUpdateConditions } from "../utils.js"
import { 
    DataPushReport,
    PriceFeed,
    PriceFeedMappers,
    PriceFeedOracles,
    PriceFeedUpdate,
    PriceFeedUpdateConditions,
} from "../types.js"

import { WitAppliance } from "./WitAppliance.js"
import { WitOracle } from "./WitOracle.js"

export class WitPriceFeeds extends WitAppliance {
    
    protected constructor (witOracle: WitOracle, at: string) {
        super(witOracle, "WitPriceFeeds", at)
    }

    static async at(witOracle: WitOracle, target: string): Promise<WitPriceFeeds> {
        const priceFeeds = new WitPriceFeeds(witOracle, target)
        let oracleAddr
        try {
            oracleAddr = await priceFeeds.contract.witOracle.staticCall()
        } catch {
            oracleAddr = await priceFeeds.provider
                .call({
                    to: target,
                    data: "0x46d1d21a", // funcSig for 'witnet()'
                })
                .then(result => AbiCoder.defaultAbiCoder().decode(["address"], result))
                .then(result => result.toString());
        }
        if (oracleAddr !== witOracle.address) {
            throw new Error(`${this.constructor.name} at ${target}: mismatching Wit/Oracle address (${oracleAddr})`)
        }
        return priceFeeds
    }

    public async createChainlinkAggregator(id4: Witnet.HexString, options?: {
        evmConfirmations?: number,
        evmGasPrice?: bigint,
        evmTimeout?: number,
        onTransaction?: (txHash: Witnet.Hash) => any,
        onTransactionReceipt?: (receipt: TransactionReceipt | null) => any,
    }): Promise<ContractTransactionReceipt | TransactionReceipt | null> {
        const evmTransaction: ContractTransaction = await this.contract
            .createChainlinkAggregator
            .populateTransaction(id4)
        evmTransaction.gasPrice = options?.evmGasPrice || evmTransaction?.gasPrice
        return this.signer
            .sendTransaction(evmTransaction)
            .then(response => {
                if (options?.onTransaction) {
                    options.onTransaction(response.hash);
                }
                return response.wait(options?.evmConfirmations || 1, options?.evmTimeout)
            })
            .then(receipt => {
                if (options?.onTransactionReceipt) {
                    options.onTransactionReceipt(receipt);
                }
                return receipt
            })
    }

    public async pushDataReport(report: DataPushReport, options?: { 
        confirmations?: number, 
        gasPrice?: bigint,
        gasLimit?: bigint,
        maxGasPrice?: bigint,
        timeout?: number,
        onTransaction?: (txHash: string) => any,
        onTransactionReceipt?: (receipt: TransactionReceipt | null) => any,
    }): Promise<ContractTransactionReceipt | TransactionReceipt | null> {
        return this.contract
            .pushDataReport
            .populateTransaction(abiEncodeDataPushReport(report), report?.evm_proof)
            .then(tx => {
                if (!options?.gasPrice && tx?.gasPrice && options?.maxGasPrice) {
                    if (tx.gasPrice > options.maxGasPrice) {
                        throw new Error(`${this.constructor.name}: network gas price too high: ${
                            formatUnits(tx.gasPrice, 9)
                            } > ${
                            formatUnits(options.maxGasPrice, 9)} gwei`)
                    }
                }
                tx.gasPrice = options?.gasPrice || tx?.gasPrice 
                tx.gasLimit = options?.gasLimit || tx?.gasLimit
                return this.signer.sendTransaction(tx)
            })
            .then(response => {
                if (options?.onTransaction) {
                    options.onTransaction(response.hash);
                }
                return response.wait(options?.confirmations || 1, options?.timeout)
            })
            .then(receipt => {
                if (options?.onTransactionReceipt) {
                    options.onTransactionReceipt(receipt);
                }
                return receipt
            })
    }

    public async settlePriceFeedRadonHash(caption: string, decimals: number, radHash: Witnet.HexString, options?: {
        evmConfirmations?: number,
        evmGasPrice?: bigint,
        evmTimeout?: number,
        onTransaction?: (txHash: Witnet.Hash) => any,
        onTransactionReceipt?: (receipt: TransactionReceipt | null) => any,
    }): Promise<ContractTransactionReceipt | TransactionReceipt | null> {
        const evmTransaction: ContractTransaction = await this.contract
            .settlePriceFeedRadonHash
            .populateTransaction(caption, decimals, radHash)
        evmTransaction.gasPrice = options?.evmGasPrice || evmTransaction?.gasPrice
        return this.signer
            .sendTransaction(evmTransaction)
            .then(response => {
                if (options?.onTransaction) {
                    options.onTransaction(response.hash);
                }
                return response.wait(options?.evmConfirmations || 1, options?.evmTimeout)
            })
            .then(receipt => {
                if (options?.onTransactionReceipt) {
                    options.onTransactionReceipt(receipt);
                }
                return receipt
            })
    }

    public async settlePriceFeedOracle(
        caption: string, 
        decimals: number, 
        oracle: PriceFeedOracles | string,
        target: Witnet.HexString,
        sources?: Witnet.HexString,
        options?: {
            evmConfirmations?: number,
            evmGasPrice?: bigint,
            evmTimeout?: number,
            onTransaction?: (txHash: Witnet.Hash) => any,
            onTransactionReceipt?: (receipt: TransactionReceipt | null) => any,
        }
    ): Promise<ContractTransactionReceipt | TransactionReceipt | null> {
        const evmTransaction: ContractTransaction = await this.contract
            .settlePriceFeedOracle
            .populateTransaction(
                caption, 
                decimals, 
                typeof oracle === "string" ? Object.values(PriceFeedOracles).indexOf(oracle) : oracle, 
                target, 
                sources || "0x0000000000000000000000000000000000000000000000000000000000000000",
            );
        evmTransaction.gasPrice = options?.evmGasPrice || evmTransaction?.gasPrice
        return this.signer
            .sendTransaction(evmTransaction)
            .then(response => {
                if (options?.onTransaction) {
                    options.onTransaction(response.hash);
                }
                return response.wait(options?.evmConfirmations || 1, options?.evmTimeout)
            })
            .then(receipt => {
                if (options?.onTransactionReceipt) {
                    options.onTransactionReceipt(receipt);
                }
                return receipt
            })
    }

    public async settlePriceFeedMapper(
        caption: string, 
        decimals: number, 
        mapper: PriceFeedMappers | string,
        dependencies: string[],
        options?: {
            evmConfirmations?: number,
            evmGasPrice?: bigint,
            evmTimeout?: number,
            onTransaction?: (txHash: Witnet.Hash) => any,
            onTransactionReceipt?: (receipt: TransactionReceipt | null) => any,
        }
    ): Promise<ContractTransactionReceipt | TransactionReceipt | null> {
        const evmTransaction: ContractTransaction = await this.contract
            .settlePriceFeedMapper
            .populateTransaction(
                caption, 
                decimals, 
                typeof mapper === "string" ? Object.values(PriceFeedMappers).indexOf(mapper) : mapper, 
                dependencies,
            );
        evmTransaction.gasPrice = options?.evmGasPrice || evmTransaction?.gasPrice
        return this.signer
            .sendTransaction(evmTransaction)
            .then(response => {
                if (options?.onTransaction) {
                    options.onTransaction(response.hash);
                }
                return response.wait(options?.evmConfirmations || 1, options?.evmTimeout)
            })
            .then(receipt => {
                if (options?.onTransactionReceipt) {
                    options.onTransactionReceipt(receipt);
                }
                return receipt
            })
    }

    public async removePriceFeed(caption: string, options?: {
        evmConfirmations?: number,
        evmGasPrice?: bigint,
        evmTimeout?: number,
        onTransaction?: (txHash: Witnet.Hash) => any,
        onTransactionReceipt?: (receipt: TransactionReceipt | null) => any,
    }): Promise<ContractTransactionReceipt | TransactionReceipt | null> {
        const evmTransaction: ContractTransaction = await this.contract
            .removePriceFeed
            .populateTransaction(caption, true);
        evmTransaction.gasPrice = options?.evmGasPrice || evmTransaction?.gasPrice
        return this.signer
            .sendTransaction(evmTransaction)
            .then(response => {
                if (options?.onTransaction) {
                    options.onTransaction(response.hash);
                }
                return response.wait(options?.evmConfirmations || 1, options?.evmTimeout)
            })
            .then(receipt => {
                if (options?.onTransactionReceipt) {
                    options.onTransactionReceipt(receipt);
                }
                return receipt
            })
    }

    public async settleDefaultUpdateConditions(conditions: PriceFeedUpdateConditions, options?: {
        evmConfirmations?: number,
        evmGasPrice?: bigint,
        evmTimeout?: number,
        onTransaction?: (txHash: Witnet.Hash) => any,
        onTransactionReceipt?: (receipt: TransactionReceipt | null) => any,
    }): Promise<ContractTransactionReceipt | TransactionReceipt | null> {
        const evmTransaction: ContractTransaction = await this.contract
            .settleDefaultUpdateConditions
            .populateTransaction(
                abiEncodePriceFeedUpdateConditions(conditions),
            );
        evmTransaction.gasPrice = options?.evmGasPrice || evmTransaction?.gasPrice
        return this.signer
            .sendTransaction(evmTransaction)
            .then(response => {
                if (options?.onTransaction) {
                    options.onTransaction(response.hash);
                }
                return response.wait(options?.evmConfirmations || 1, options?.evmTimeout)
            })
            .then(receipt => {
                if (options?.onTransactionReceipt) {
                    options.onTransactionReceipt(receipt);
                }
                return receipt
            })
    }

    public async settlePriceFeedUpdateConditions(caption: string, conditions: PriceFeedUpdateConditions, options?: {
        evmConfirmations?: number,
        evmGasPrice?: bigint,
        evmTimeout?: number,
        onTransaction?: (txHash: Witnet.Hash) => any,
        onTransactionReceipt?: (receipt: TransactionReceipt | null) => any,
    }): Promise<ContractTransactionReceipt | TransactionReceipt | null> {
        const evmTransaction: ContractTransaction = await this.contract
            .settlePriceFeedUpdateConditions
            .populateTransaction(
                caption,
                abiEncodePriceFeedUpdateConditions(conditions),
            );
        evmTransaction.gasPrice = options?.evmGasPrice || evmTransaction?.gasPrice
        return this.signer
            .sendTransaction(evmTransaction)
            .then(response => {
                if (options?.onTransaction) {
                    options.onTransaction(response.hash);
                }
                return response.wait(options?.evmConfirmations || 1, options?.evmTimeout)
            })
            .then(receipt => {
                if (options?.onTransactionReceipt) {
                    options.onTransactionReceipt(receipt);
                }
                return receipt
            })
    }

    public async clone(curator: string, options?: {
        evmConfirmations?: number,
        evmGasPrice?: bigint,
        evmTimeout?: number,
        onTransaction?: (TxHash: Witnet.Hash) => any,
        onTransactionReceipt?: (receipt: TransactionReceipt | null) => any,
    }): Promise<ContractTransactionReceipt | TransactionReceipt | null> {
        const tx: ContractTransaction = await this.contract.clone.populateTransaction(curator)
        tx.gasPrice = options?.evmGasPrice || tx?.gasPrice
        return this.signer
            .sendTransaction(tx)
            .then(response => {
                if (options?.onTransaction) {
                    options.onTransaction(response.hash)
                }
                return response.wait(options?.evmConfirmations || 1, options?.evmTimeout)
            })
            .then(receipt => {
                if (options?.onTransactionReceipt) {
                    options.onTransactionReceipt(receipt)
                }
                return receipt;
            })
    }

    public async getDefaultUpdateConditions(): Promise<PriceFeedUpdateConditions> {
        return this.contract
            .defaultUpdateConditions
            .staticCall()
    }

    public async determineChainlinkAggregatorAddress(id4: Witnet.HexString): Promise<string> {
        return this.contract
            .createChainlinkAggregator
            .staticCall(id4)
    }

    public async getEvmClonableBase(): Promise<string> {
        return this.contract
            .base
            .staticCall()
    }

    public async getEvmConsumer(): Promise<Witnet.HexString> {
        return this.contract
            .consumer
            .staticCall()
    }

    public async getEvmCurator(): Promise<Witnet.HexString> {
        return this.contract
            .owner
            .staticCall()
    }

    public async getEvmFootprint(): Promise<string> {
        return this.contract
            .footprint
            .staticCall()
    }

    public async getId4(caption: string): Promise<Witnet.HexString> {
        return this.contract
            .hash
            .staticCall(caption)
            .then(id => id.slice(0, 10))
    }

    public async getPrice(id4: Witnet.HexString): Promise<PriceFeedUpdate> {
        return this.contract
            .getFunction("getPrice(bytes4)")
            .staticCall(id4)
            .then((result: any) => ({
                price: Number(result.price) / 10 ** Number(-result.exponent),
                deltaPrice: Number(result.deltaPrice) / 10 ** Number(-result.exponent),
                exponent: Number(result.exponent),
                timestamp: Number(result.timestamp),
                trail: result.trail,
            }))
    }

    public async getPriceNotOlderThan(id4: Witnet.HexString, age: number): Promise<PriceFeedUpdate> {
        return this.contract
            .getFunction("getPriceNotOlderThan(bytes4,uint24)")
            .staticCall(id4, age)
            .then((result: any) => ({
                price: Number(result.price) / 10 ** Number(-result.exponent),
                deltaPrice: Number(result.deltaPrice) / 10 ** Number(-result.exponent),
                exponent: Number(result.exponent),
                timestamp: Number(result.timestamp),
                trail: result.trail,
            }))
    }

    public async getPriceUnsafe(id4: Witnet.HexString): Promise<PriceFeedUpdate> {
        return this.contract
            .getFunction("getPriceUnsafe(bytes4)")
            .staticCall(id4)
            .then((result: any) => ({
                price: Number(result.price) / 10 ** Number(-result.exponent),
                deltaPrice: Number(result.deltaPrice) / 10 ** Number(-result.exponent),
                exponent: Number(result.exponent),
                timestamp: Number(result.timestamp),
                trail: result.trail,
            }))
    }

    public async isCaptionSupported(caption: string): Promise<boolean> {
        return this.contract
            .supportsCaption
            .staticCall(caption)
    }

    public async lookupPriceFeed(id4: Witnet.HexString): Promise<PriceFeed> {
        return this.contract
            .lookupPriceFeed
            .staticCall(id4)
            .then((result: any) => ({
                id: result.id,
                id4: result.id.slice(0, 10),
                exponent: Number(result.exponent),
                symbol: result.symbol,
                ...(result.mapper.class !== 0n ? { 
                    mapper: {
                        class: PriceFeedMappers[result.mapper.class],
                        deps: result.mapper.deps,
                    }
                } : {
                    oracle: {
                        class: PriceFeedOracles[result.oracle.class],
                        target: result.oracle.target,
                        sources: result.oracle.sources,
                    },
                }),
                updateConditions: {
                    callbackGas: Number(result.updateConditions.callbackGas),
                    computeEMA: result.updateConditions.computeEma,
                    cooldownSecs: Number(result.updateConditions.cooldownSecs),
                    heartbeatSecs: Number(result.updateConditions.heartbeatSecs),
                    maxDeviationPercentage: Number(result.updateConditions.maxDeviation1000) / 10,
                    minWitnesses: Number(result.updateConditions.minWitnesses),
                },
                lastUpdate: {
                    price: Number(result.lastUpdate.price) / 10 ** Number(-result.lastUpdate.exponent),
                    deltaPrice: Number(result.lastUpdate.deltaPrice) / 10 ** Number(-result.lastUpdate.exponent),
                    exponent: Number(result.lastUpdate.exponent),
                    timestamp: Number(result.lastUpdate.timestamp),
                    trail: result.lastUpdate.trail,
                },
            }))
    }

    public async lookupPriceFeedCaption(id4: Witnet.HexString): Promise<string> {
        return this.contract
            .lookupSymbol
            .staticCall(id4)
    }

    public async lookupPriceFeedExponent(id4: Witnet.HexString): Promise<number> {
        return this.contract
            .lookupPriceFeedExponent
            .staticCall(id4)
            .then(result => Number(result))
    }

    public async lookupPriceFeedID(id4: Witnet.HexString): Promise<Witnet.Hash> {
        return this.contract
            .lookupPriceFeedID
            .staticCall(id4)
    }

    public async lookupPriceFeeds(): Promise<Array<PriceFeed>> {
        return this.contract
            .lookupPriceFeeds
            .staticCall()
            .then(results => results.map((result: any) => ({
                id: result.id,
                id4: result.id.slice(0, 10),
                exponent: Number(result.exponent),
                symbol: result.symbol,
                ...(result.mapper.class !== 0n ? { 
                    mapper: {
                        class: PriceFeedMappers[result.mapper.class],
                        deps: result.mapper.deps,
                    }
                } : {
                    oracle: {
                        class: PriceFeedOracles[result.oracle.class],
                        target: result.oracle.target,
                        sources: result.oracle.sources,
                    },
                }),
                updateConditions: {
                    callbackGas: Number(result.updateConditions.callbackGas),
                    computeEMA: result.updateConditions.computeEma,
                    cooldownSecs: Number(result.updateConditions.cooldownSecs),
                    heartbeatSecs: Number(result.updateConditions.heartbeatSecs),
                    maxDeviationPercentage: Number(result.updateConditions.maxDeviation1000) / 10,
                    minWitnesses: Number(result.updateConditions.minWitnesses)
                },
                lastUpdate: {
                    price: Number(result.lastUpdate.price) / 10 ** Number(-result.lastUpdate.exponent),
                    deltaPrice: Number(result.lastUpdate.deltaPrice) / 10 ** Number(-result.lastUpdate.exponent),
                    exponent: Number(result.lastUpdate.exponent),
                    timestamp: BigInt(result.lastUpdate.timestamp),
                    trail: result.lastUpdate.trail,
                },
            })));
    }

}
