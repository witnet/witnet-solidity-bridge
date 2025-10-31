import { utils, Witnet } from "@witnet/sdk"
import type { ContractTransactionReceipt, JsonRpcSigner, Result } from "ethers"
import { abiEncodeRadonAsset } from "../utils.js"
import { WitArtifact } from "./WitArtifact.js"

/**
 * Wrapper class for the Wit/Oracle Radon Registry core contract as deployed in some supported EVM network.
 * It allows formal verification of Radon Requests and Witnet-compliant data sources into such network,
 * as to be securely referred on both Wit/Oracle queries pulled from within smart contracts,
 * or Wit/Oracle query results pushed into smart contracts from offchain workflows.
 */
export class WitOracleRadonRegistry extends WitArtifact {
	constructor(signer: JsonRpcSigner, network: string) {
		super(signer, network, "WitOracleRadonRegistry")
	}

	/// ===========================================================================================================
	/// --- IWitOracleRadonRegistry -------------------------------------------------------------------------------

	/**
	 * Determines the unique hash that would identify the given Radon Retrieval, if it was
	 * formally verified into the connected EVM network.
	 * @param retrieval Instance of a Radon Retrieval object.
	 */
	public async determineRadonRetrievalHash(
		retrieval: Witnet.Radon.RadonRetrieval,
	): Promise<string> {
		return this.contract
			.getFunction(
				"verifyRadonRetrieval(uint8,string,string,string[2][],bytes)",
			)
			.staticCall(...abiEncodeRadonAsset(retrieval))
			.then((hash) => {
				return hash.slice(2)
			})
	}

	/**
	 * Returns information related to some previously verified Radon Request, on the connected EVM network.
	 * @param radHash The RAD hash that uniquely identifies the Radon Request.
	 */
	public async lookupRadonRequest(
		radHash: string,
	): Promise<Witnet.Radon.RadonRequest> {
		return this.contract
			.getFunction("lookupRadonRequestBytecode(bytes32)")
			.staticCall(`0x${radHash}`)
			.then((bytecode) => Witnet.Radon.RadonRequest.fromBytecode(bytecode))
	}

	/**
	 * Returns the bytecode of some previously verified Radon Request, on the connected EVM network.
	 * @param radHash The RAD hash that uniquely identifies the Radon Request.
	 */
	public async lookupRadonRequestBytecode(
		radHash: string,
	): Promise<Witnet.HexString> {
		return this.contract
			.getFunction("lookupRadonRequestBytecode(bytes32)")
			.staticCall(`${radHash.startsWith("0x") ? radHash : `0x${radHash}`}`)
	}

	/**
	 * Returns information about some previously verified Radon Retrieval on the connected EVM network.
	 * This information includes retrieval the method, URL, body, headers and the Radon script in charge
	 * to transform data before delivery, on the connected EVM network.
	 * @param radHash The RAD hash that uniquely identifies the Radon Request.
	 */
	public async lookupRadonRetrieval(
		hash: string,
	): Promise<Witnet.Radon.RadonRetrieval> {
		return this.contract
			.getFunction("lookupRadonRetrieval(bytes32)")
			.staticCall(`0x${hash}`)
			.then((result: Result) => {
				return new Witnet.Radon.RadonRetrieval({
					method: result[1],
					url: result[3],
					body: result[4],
					headers: Object.fromEntries(result[5]),
					script: utils.parseRadonScript(result[6]),
				})
			})
	}

	/**
	 * Formally verify the given Radon Request object into the connected EVM network.
	 * It also verifies all the Radon Retrieval scripts (i.e. data source) the Request
	 * relies on, if not yet done before.
	 *
	 * Verifying Radon assets modifies the EVM storage and therefore requires
	 * spending gas in proportion to the number and complexity of the data sources,
	 * and whether these had been previously verified before or not.
	 *
	 * If the given Radon Request happened to be already verified, no gas would be actually consumed.
	 *
	 * @param request Instance of a Radon Request object.
	 * @param options Async EVM transaction handlers.
	 * @returns The RAD hash of the Radon Request, as verified on the connected EVM network.
	 */
	public async verifyRadonRequest(
		request: Witnet.Radon.RadonRequest,
		options?: {
			/**
			 * Number of block confirmations to wait for after verifying transaction gets mined (defaults to 1).
			 */
			confirmations?: number
			/**
			 * Callback handler called just in case a `verifyRadonRequest` transaction is ultimately required.
			 */
			onVerifyRadonRequest: (radHash: string) => any
			/**
			 * Callback handler called once the `verifyRadonRequest` transaction gets confirmed.
			 * @param receipt The `verifyRadonRequest` transaction receipt.
			 */
			onVerifyRadonRequestReceipt?: (
				receipt: ContractTransactionReceipt | null,
			) => any
			/**
			 * Callback handler called for every involved `verifyRadonRetrieval` transaction.
			 */
			onVerifyRadonRetrieval?: (hash: string) => any
			/**
			 * Callback handler called after every involved `verifyRadonRetrieval` transaction gets confirmed.
			 * @param receipt The `verifyRadonRetrieval` transaction receipt.
			 */
			onVerifyRadonRetrievalReceipt?: (
				receipt: ContractTransactionReceipt | null,
			) => any
		},
	): Promise<string> {
		const radHash = request.radHash
		await this.lookupRadonRequest(radHash).catch(async () => {
			const hashes: Array<string> = []
			for (const index in request.sources) {
				const retrieval = request.sources[index]
				hashes.push(`0x${await this.verifyRadonRetrieval(retrieval, options)}`)
			}
			const aggregate = abiEncodeRadonAsset(request.sourcesReducer)
			const tally = abiEncodeRadonAsset(request.witnessReducer)
			if (options?.onVerifyRadonRequest) {
				options.onVerifyRadonRequest(radHash)
			}
			await this.contract
				.getFunction(
					"verifyRadonRequest(bytes32[],(uint8,(uint8,bytes)[]),(uint8,(uint8,bytes)[]))",
				)
				.send(hashes, aggregate, tally)
				.then(async (tx) => {
					const receipt = await tx.wait(options?.confirmations || 1)
					if (options?.onVerifyRadonRequestReceipt) {
						options.onVerifyRadonRequestReceipt(receipt)
					}
				})
		})
		return radHash
	}

	/**
	 * Formally verify the given Radon Retrieval script (i.e. data source), into the connected EVM network.
	 *
	 * Verifying Radon assets modifies the EVM storage and therefore requires
	 * spending gas in proportion to the size of the data source parameters (e.g. URL, body, headers, or Radon script).
	 *
	 * If the given Radon Retrieval object happened to be already verified, no EVM gas would be actually consumed.
	 *
	 * @param request Instance of a Radon Retrieval object.
	 * @param options Async EVM transaction handlers.
	 * @returns The unique hash of the Radon Retrieval object, as verified on the connected EVM network.
	 */
	public async verifyRadonRetrieval(
		retrieval: Witnet.Radon.RadonRetrieval,
		options?: {
			/**
			 * Number of block confirmations to wait for after verifying transaction gets mined (defaults to 1).
			 */
			confirmations?: number
			/**
			 * Callback handler called just in case a `verifyRadonRequest` transaction is ultimately required.
			 */
			onVerifyRadonRetrieval?: (hash: string) => any
			/**
			 * Callback handler called once the `verifyRadonRetrieval` transaction gets confirmed.
			 * @param receipt The `verifyRadonRetrieval` transaction receipt.
			 */
			onVerifyRadonRetrievalReceipt?: (
				receipt: ContractTransactionReceipt | null,
			) => any
		},
	): Promise<string> {
		return this.determineRadonRetrievalHash(retrieval).then(async (hash) => {
			await this.lookupRadonRetrieval(hash).catch(async () => {
				if (options?.onVerifyRadonRetrieval) {
					options.onVerifyRadonRetrieval(hash)
				}
				await this.contract
					.getFunction(
						"verifyRadonRetrieval(uint8,string,string,string[2][],bytes)",
					)
					.send(...abiEncodeRadonAsset(retrieval))
					.then(async (tx) => {
						const receipt = await tx.wait(options?.confirmations || 1)
						if (options?.onVerifyRadonRetrievalReceipt) {
							options.onVerifyRadonRetrievalReceipt(receipt)
						}
					})
			})
			return hash
		})
	}
}
