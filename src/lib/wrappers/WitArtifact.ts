import type { Addressable, ContractRunner, Interface, InterfaceAbi, JsonRpcSigner } from "ethers";
import { ABIs } from "../../index.js";
import { fetchEvmNetworkFromProvider, getEvmNetworkAddresses } from "../utils.js";
import { ContractWrapper } from "./ContractWrapper.js";

export abstract class WitArtifact extends ContractWrapper {
	constructor(specs: {
		artifact: string;
		network: string;
		networkId: number;
		runner: ContractRunner;
		target?: string | Addressable;
	}) {
		const abis: Record<string, Interface | InterfaceAbi> = ABIs;
		const target = specs?.target || getEvmNetworkAddresses(specs.network)?.core[specs.artifact];
		if (!abis[specs.artifact] || !target) {
			throw new Error(`EVM network ${specs.network} => unavailable framework artifact: ${specs.artifact}`);
		} else {
			super(target, abis[specs.artifact], specs.runner);
		}
		this.network = specs.network;
		this.networkId = specs.networkId;
	}

	/**
	 * The EVM network name as known by the Witnet Framework (e.g. "ethereum:mainnet", "ethereum:sepolia", etc.)
	 */
	public readonly network: string;

	/**
	 * The EVM network chain ID (e.g. 1 for Ethereum mainnet, 11155111 for Sepolia, etc.)
	 */
	public readonly networkId: number;

	/**
	 * Connect the contract wrapper to a different ContractRunner (e.g. signer or provider).
	 * Fails if the new provider's network does not match the artifact's network.
	 * @param runner
	 * @returns
	 */
	public async connect(runner: ContractRunner): Promise<WitArtifact> {
		const [provider] = this._getProviderAndSignerFromContractRunner(runner);
		return fetchEvmNetworkFromProvider(provider).then((network) => {
			if (!network || network.id !== this.networkId) {
				throw new Error(
					`Connected provider network (chainId: ${network?.id}) does not match the artifact's network (chainId: ${this.networkId})`,
				);
			} else {
				super.connect(runner);
				return this;
			}
		});
	}

	/**
	 * Check if a signer is available for contract interactions.
	 * @returns The signer if available, otherwise throws an error.
	 */
	protected _checkSigner(): JsonRpcSigner {
		if (!this.signer) {
			throw new Error(`${this.constructor.name}: No signer available in EVM network ${this.network}.`);
		} else {
			return this.signer;
		}
	}
}
