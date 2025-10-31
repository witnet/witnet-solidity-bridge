import { Witnet } from "@witnet/sdk"
import type { ContractTransactionReceipt, Result } from "ethers"
import type { WitOracleResultDataTypes } from "../types.js"
import { abiEncodeRadonAsset, parseRadonScript } from "../utils.js"
import { WitAppliance } from "./WitAppliance.js"
import type { WitOracle } from "./WitOracle.js"
import type { WitOracleRadonRegistry } from "./WitOracleRadonRegistry.js"

export class WitOracleRadonRequestFactory extends WitAppliance {
	public readonly registry: WitOracleRadonRegistry

	protected constructor(
		witOracle: WitOracle,
		registry: WitOracleRadonRegistry,
		at?: string,
	) {
		super(witOracle, "WitOracleRadonRequestFactory", at)
		this.registry = registry
	}

	static async deployed(
		witOracle: WitOracle,
		registry: WitOracleRadonRegistry,
	): Promise<WitOracleRadonRequestFactory> {
		const deployer = new WitOracleRadonRequestFactory(witOracle, registry)
		const witOracleRegistryAddress =
			await witOracle.contract.registry.staticCall()
		if (registry.address !== witOracleRegistryAddress) {
			throw new Error(
				`${WitOracleRadonRequestFactory.constructor.name} at ${deployer.address}: uncompliant WitOracleRadonRegistry at ${registry.address})`,
			)
		}
		return deployer
	}

	public async deployRadonRequestTemplate(
		template: Witnet.Radon.RadonTemplate,
		options?: {
			confirmations?: number
			onDeployRadonRequestTemplate?: (address: string) => any
			onDeployRadonRequestTemplateReceipt?: (
				receipt: ContractTransactionReceipt | null,
			) => any
			/**
			 * Callback handler called just in case a `verifyRadonRetrieval` transaction is ultimately required.
			 */
			onVerifyRadonRetrieval?: (hash: string) => any
			/**
			 * Callback handler called once the `verifyRadonRetrieval` transaction gets confirmed.
			 * @param receipt The `verifyRadonRetrieval` transaction receipt.
			 * @param hash The unique hash of the Radon Retrieval, as verified on the connected network.
			 */
			onVerifyRadonRetrievalReceipt?: (
				receipt: ContractTransactionReceipt | null,
			) => any
		},
	): Promise<WitOracleRadonRequestTemplate> {
		const hashes: Array<string> = []
		for (const index in template.sources) {
			const retrieval = template.sources[index]
			const hash = `0x${await this.registry.determineRadonRetrievalHash(retrieval)}`
			await this.registry.verifyRadonRetrieval(retrieval, options)
			hashes.push(hash)
		}

		const aggregator = abiEncodeRadonAsset(template.sourcesReducer)
		const tally = abiEncodeRadonAsset(template.witnessReducer)
		const target = await this.contract
			.getFunction(
				"buildRadonRequestTemplate(bytes32[],(uint8,(uint8,bytes)[]),(uint8,(uint8,bytes)[]))",
			)
			.staticCall(hashes, aggregator, tally)

		if (options?.onDeployRadonRequestTemplate)
			options.onDeployRadonRequestTemplate(target)
		await this.contract
			.getFunction(
				"buildRadonRequestTemplate(bytes32[],(uint8,(uint8,bytes)[]),(uint8,(uint8,bytes)[]))",
			)
			.send(hashes, aggregator, tally)
			.then(async (tx) => {
				const receipt = await tx.wait(options?.confirmations || 1)
				if (options?.onDeployRadonRequestTemplateReceipt) {
					options.onDeployRadonRequestTemplateReceipt(receipt)
				}
			})

		return await WitOracleRadonRequestTemplate.at(this.witOracle, target)
	}

	public async deployRadonRequestModal(
		modal: Witnet.Radon.RadonModal,
		options?: {
			confirmations?: number
			onDeployRadonRequestModal?: (address: string) => any
			onDeployRadonRequestModalReceipt?: (
				receipt: ContractTransactionReceipt | null,
			) => any
			/**
			 * Callback handler called just in case a `verifyRadonRetrieval` transaction is ultimately required.
			 */
			onVerifyRadonRetrieval?: (hash: string) => any
			/**
			 * Callback handler called once the `verifyRadonRetrieval` transaction gets confirmed.
			 * @param receipt The `verifyRadonRetrieval` transaction receipt.
			 * @param hash The unique hash of the Radon Retrieval, as verified on the connected network.
			 */
			onVerifyRadonRetrievalReceipt?: (
				receipt: ContractTransactionReceipt | null,
			) => any
		},
	): Promise<WitOracleRadonRequestModal> {
		const retrieval = [
			modal.sources[0].method,
			modal.sources[0].body || "",
			modal.sources[0]?.headers ? Object.entries(modal.sources[0].headers) : [],
			modal.sources[0].script?.toBytecode() || "0x",
		]
		const tally = abiEncodeRadonAsset(modal.witnessReducer)
		const target = await this.contract.buildRadonRequestModal //getFunction("buildRadonRequestModal((uint8,string,string[2][],bytes),(uint8,(uint8,bytes)[]))")
			.staticCall(retrieval, tally)

		if (options?.onDeployRadonRequestModal)
			options.onDeployRadonRequestModal(target)
		await this.contract.buildRadonRequestModal
			// .getFunction("buildRadonRequestModal((uint8,string,string[2][],bytes),(uint8,(uint8,bytes)[]))")
			.send(retrieval, tally)
			.then(async (tx) => {
				const receipt = await tx.wait(options?.confirmations || 1)
				if (options?.onDeployRadonRequestModalReceipt) {
					options.onDeployRadonRequestModalReceipt(receipt)
				}
			})

		return await WitOracleRadonRequestModal.at(this.witOracle, target)
	}

	public async verifyRadonRequest(
		request: Witnet.Radon.RadonRequest,
		_options?: {
			confirmations?: number
			onVerifyRadonRequest?: (address: string) => any
			onVerifyRadonRequestReceipt?: (
				receipt: ContractTransactionReceipt | null,
			) => any
			/**
			 * Callback handler called just in case a `verifyRadonRetrieval` transaction is ultimately required.
			 */
			onVerifyRadonRetrieval?: (hash: string) => any
			/**
			 * Callback handler called once the `verifyRadonRetrieval` transaction gets confirmed.
			 * @param receipt The `verifyRadonRetrieval` transaction receipt.
			 * @param hash The unique hash of the Radon Retrieval, as verified on the connected network.
			 */
			onVerifyRadonRetrievalReceipt?: (
				receipt: ContractTransactionReceipt | null,
			) => any
		},
	): Promise<Witnet.Hash> {
		// TODO:
		//
		return request.radHash
	}
}

export class WitOracleRadonRequestModal extends WitAppliance {
	protected constructor(witOracle: WitOracle, at: string) {
		super(witOracle, "WitOracleRadonRequestModal", at)
	}

	static async at(
		witOracle: WitOracle,
		target: string,
	): Promise<WitOracleRadonRequestModal> {
		const template = new WitOracleRadonRequestModal(witOracle, target)
		const templateWitOracleAddr = await template.contract.witOracle.staticCall()
		if (templateWitOracleAddr !== witOracle.address) {
			throw new Error(
				`${WitOracleRadonRequestModal.constructor.name} at ${target}: mismatching Wit/Oracle address (${templateWitOracleAddr})`,
			)
		}
		return template
	}

	public async getDataResultType(): Promise<WitOracleResultDataTypes> {
		return this.contract
			.getFunction("getDataResultType()")
			.staticCall()
			.then((result: number) => {
				switch (Number(result)) {
					case 1:
						return "array"
					case 2:
						return "boolean"
					case 3:
						return "bytes"
					case 4:
						return "integer"
					case 5:
						return "float"
					case 6:
						return "map"
					case 7:
						return "string"
					default:
						return "any"
				}
			})
	}

	public async getDataSourcesArgsCount(): Promise<number> {
		return this.contract
			.getFunction("getDataSourcesArgsCount()")
			.staticCall()
			.then((argsCount: bigint) => Number(argsCount))
	}

	public async getRadonModalRetrieval(): Promise<Witnet.Radon.RadonRetrieval> {
		return this.contract
			.getFunction("getRadonModalRetrieval()")
			.staticCall()
			.then((result: Result) => {
				return new Witnet.Radon.RadonRetrieval({
					method: result[1],
					url: result[3],
					body: result[4],
					headers: Object.fromEntries(result[5]),
					script: parseRadonScript(result[6]),
				})
			})
	}

	public async verifyRadonRequest(
		dataProviders: string[],
		commonRetrievalArgs?: string[],
		options?: {
			confirmations?: number
			onVerifyRadonRequest: (radHash: string) => any
			onVerifyRadonRequestReceipt: (
				receipt: ContractTransactionReceipt | null,
			) => any
		},
	): Promise<Witnet.Hash> {
		const argsCount = await this.getDataSourcesArgsCount()
		if (argsCount != 1 + (commonRetrievalArgs?.length || 0)) {
			throw TypeError(
				`${this.constructor.name}@${this.address}: unmatching args count != ${argsCount - 1}.`,
			)
		}
		const method = this.contract.getFunction(
			"verifyRadonRequest(string[],string[])",
		)
		const radHash = (
			await method.staticCall(commonRetrievalArgs || [], dataProviders)
		).slice(2)
		try {
			await (
				await this.witOracle.getWitOracleRadonRegistry()
			).lookupRadonRequestBytecode(radHash)
		} catch {
			if (options?.onVerifyRadonRequest) options.onVerifyRadonRequest(radHash)
			await method
				.send(commonRetrievalArgs || [], dataProviders)
				.then((tx) => tx.wait(options?.confirmations || 1))
				.then((receipt) => {
					if (options?.onVerifyRadonRequestReceipt) {
						options.onVerifyRadonRequestReceipt(receipt)
					}
					return radHash
				})
		}
		return radHash
	}
}

export class WitOracleRadonRequestTemplate extends WitAppliance {
	protected constructor(witOracle: WitOracle, at: string) {
		super(witOracle, "WitOracleRadonRequestTemplate", at)
	}

	static async at(
		witOracle: WitOracle,
		target: string,
	): Promise<WitOracleRadonRequestTemplate> {
		const template = new WitOracleRadonRequestTemplate(witOracle, target)
		const templateWitOracleAddr = await template.contract.witOracle.staticCall()
		if (templateWitOracleAddr !== witOracle.address) {
			throw new Error(
				`${WitOracleRadonRequestTemplate.constructor.name} at ${target}: mismatching Wit/Oracle address (${templateWitOracleAddr})`,
			)
		}
		return template
	}

	public async getDataResultType(): Promise<WitOracleResultDataTypes> {
		return this.contract
			.getFunction("getDataResultType()")
			.staticCall()
			.then((result: number) => {
				switch (Number(result)) {
					case 1:
						return "array"
					case 2:
						return "boolean"
					case 3:
						return "bytes"
					case 4:
						return "integer"
					case 5:
						return "float"
					case 6:
						return "map"
					case 7:
						return "string"
					default:
						return "any"
				}
			})
	}

	public async getDataSources(): Promise<Array<Witnet.Radon.RadonRetrieval>> {
		return this.contract
			.getFunction("getDataSources()")
			.staticCall()
			.then((results: Array<Result>) => {
				return results.map(
					(result) =>
						new Witnet.Radon.RadonRetrieval({
							method: result[1],
							url: result[3],
							body: result[4],
							headers: Object.fromEntries(result[5]),
							script: parseRadonScript(result[6]),
						}),
				)
			})
	}

	public async getDataSourcesArgsCount(): Promise<Array<number>> {
		return this.contract
			.getFunction("getDataSourcesArgsCount()")
			.staticCall()
			.then((dims: Array<bigint>) => dims.map((dim) => Number(dim)))
	}

	public async verifyRadonRequest(
		args: string | string[] | Array<string[]>,
		options?: {
			confirmations?: number
			onVerifyRadonRequest: (radHash: string) => any
			onVerifyRadonRequestReceipt: (
				receipt: ContractTransactionReceipt | null,
			) => any
		},
	): Promise<Witnet.HexString> {
		const argsCount = await this.getDataSourcesArgsCount()
		let encodedArgs: Array<string[]> = []
		if (typeof args === "string") {
			if (argsCount.length === 1 && argsCount[0] === 1) {
				encodedArgs = [[args as string]]
			}
		} else if (Array.isArray(args)) {
			if (Array.isArray(args[0])) {
				if (
					argsCount.length === args.length &&
					!args.find((subargs, index) => subargs.length !== argsCount[index])
				) {
					encodedArgs = args as Array<string[]>
				}
			} else if (
				args.length === argsCount[0] &&
				!args.find((arg) => typeof arg !== "string")
			) {
				encodedArgs = [args as string[]]
			}
		}
		if (encodedArgs.length === 0) {
			throw TypeError(
				`${this.constructor.name}@${this.address}: unmatching args count != [${argsCount}, ].`,
			)
		}
		const method = this.contract.getFunction("verifyRadonRequest(string[][])")
		const radHash = (await method.staticCall(encodedArgs)).slice(2)
		try {
			await (
				await this.witOracle.getWitOracleRadonRegistry()
			).lookupRadonRequestBytecode(radHash)
		} catch {
			if (options?.onVerifyRadonRequest) options.onVerifyRadonRequest(radHash)
			await method
				.send(encodedArgs)
				.then((tx) => tx.wait(options?.confirmations || 1))
				.then((receipt) => {
					if (options?.onVerifyRadonRequestReceipt) {
						options.onVerifyRadonRequestReceipt(receipt)
					}
					return radHash
				})
		}
		return radHash
	}
}
