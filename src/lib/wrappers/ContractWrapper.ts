import {
	AbiCoder,
	type Addressable,
	Contract,
	type ContractRunner,
	type Interface,
	type InterfaceAbi,
	type JsonRpcApiProvider,
	JsonRpcSigner,
} from "ethers";

export abstract class ContractWrapper {
	constructor(target: string | Addressable, abi: Interface | InterfaceAbi, runner: ContractRunner) {
		this.abi = abi;
		this._address = target;
		this._contract = new Contract(target, abi, runner);
		this._runner = runner;
		[this._provider, this._signer] = this._getProviderAndSignerFromContractRunner(runner);
	}

	/**
	 * Check if a signer is available for contract interactions.
	 * @returns The signer if available, otherwise throws an error.
	 */
	protected _checkSigner(): JsonRpcSigner {
		if (!this.signer) {
			throw new Error(`${this.constructor.name}: No signer is available.`);
		} else {
			return this.signer;
		}
	}

	/**
	 * Get the provider and signer from a ContractRunner.
	 * @param runner The ContractRunner to extract the provider and signer from.
	 * @return An array containing the provider and signer (if available).
	 * @throws An error if the ContractRunner does not have a provider property.
	 * @remarks The method checks if the runner has a provider property, and if so, it returns the provider and signer (if the runner is a JsonRpcSigner). If the runner does not have a provider property, it throws an error.
	 * @example
	 * // Assuming `contractWrapper` is an instance of a class that extends ContractWrapper:
	 * const provider = contractWrapper.provider; // Get the provider
	 * const signer = contractWrapper.signer; // Get the signer (if available)
	 */
	protected _getProviderAndSignerFromContractRunner(runner: ContractRunner): any[] {
		if ("provider" in runner) {
			return [
				runner.provider as JsonRpcApiProvider,
				// ...this._getNetworkFromProvider(runner.provider as JsonRpcApiProvider),
				runner instanceof JsonRpcSigner ? (runner as JsonRpcSigner) : undefined,
			];
		} else {
			throw new Error(`${this.constructor.name}: ContractRunner does not have provider property`);
		}
	}

	protected _address: string | Addressable;
	protected _contract: Contract;
	protected _provider: JsonRpcApiProvider;
	protected _runner: ContractRunner;
	protected _signer?: JsonRpcSigner;

	/**
	 * Attach the contract wrapper to a different address.
	 * @param target New address to attach to.
	 * @returns The contract wrapper instance, connected to the new address.
	 */
	public async attach(target: string | Addressable): Promise<ContractWrapper> {
		this._contract = this._contract.attach(target) as Contract;
		this._address = target;
		return this;
	}

	/**
	 * Connect the contract wrapper to a different ContractRunner (e.g. signer or provider).
	 * @param runner New ContractRunner to connect to.
	 * @returns The contract wrapper instance, connected to the new ContractRunner.
	 */
	protected async connect(runner: ContractRunner): Promise<ContractWrapper> {
		[this._provider, this._signer] = this._getProviderAndSignerFromContractRunner(runner);
		this._contract = this._contract.connect(runner) as Contract;
		this._runner = runner;
		return this;
	}

	/**
	 * The contract's ABI.
	 */
	public readonly abi: Interface | InterfaceAbi;

	/**
	 * The address of the underlying Wit/Oracle Framework artifact.
	 */
	public get address(): string | Addressable {
		return this._address;
	}

	/**
	 * The underlying Ethers' contract wrapper.
	 */
	public get contract(): Contract {
		return this._contract;
	}

	/**
	 * The ETH/RPC provider used of contract interactions.
	 */
	public get provider(): JsonRpcApiProvider {
		return this._provider;
	}

	/**
	 * The ContractRunner (e.g. signer or provider) used for contract interactions.
	 */
	public get runner(): ContractRunner {
		return this._runner;
	}

	/**
	 * The EVM address that will sign contract interaction transactions, when required.
	 */
	public get signer(): JsonRpcSigner | undefined {
		return this._signer;
	}

	// public readonly runner: ContractRunner;
	/**
	 * Name of the underlying logic implementation contract.
	 * @returns Contract name.
	 */
	public async getEvmImplClass(): Promise<string> {
		return this.contract.getFunction("class()").staticCall();
	}

	/**
	 * Get specs identifier of the underlying logic implementation contract.
	 * @returns 4-byte hex string.
	 */
	public async getEvmImplSpecs(): Promise<string> {
		return this.contract.getFunction("specs()").staticCall();
	}

	/**
	 * Version tag of the underlying logic implementation contract.
	 * @returns Version tag.
	 */
	public async getEvmImplVersion(): Promise<string> {
		let version;
		try {
			version = await this.provider
				.call({
					to: this.address,
					data: "0x54fd4d50", // funcSig for 'version()'
				})
				.then((result) => AbiCoder.defaultAbiCoder().decode(["string"], result))
				.then((result) => result.toString());
		} catch (_err) {
			return "(immutable)";
		}
		return version;
	}

	/**
	 * Set the contract wrapper's signer to a different address, and connect the underlying contract to it.
	 * If the contract wrapper was not connected to a signer before, it will now be able to sign transactions.
	 * If the contract wrapper was already connected to a signer, it will now be connected to the new signer.
	 * @param address Address or index of the new signer to set. If not provided, the default signer will be used.
	 * @returns The new signer.
	 */
	public async setSigner(address?: number | string): Promise<JsonRpcSigner> {
		return this._provider.getSigner(address).then((signer) => {
			this._signer = signer;
			this._contract = this._contract.connect(signer) as Contract;
			return signer;
		});
	}
}
