import type { Addressable, Interface, InterfaceAbi } from "ethers";
import { ABIs } from "../../index.js";
import { getEvmNetworkAddresses } from "../utils.js";
import type { WitOracle } from "./WitOracle.js";
import { WitArtifact } from "./WitArtifact.js";

export abstract class WitAppliance extends WitArtifact {
	
	public readonly witOracle: WitOracle;

	constructor(specs: {
		artifact: string,
		target?: string | Addressable,
		witOracle: WitOracle,
	}) {
		const { artifact, target: at, witOracle } = specs;
		const abis: Record<string, Interface | InterfaceAbi> = ABIs;
		const addresses = getEvmNetworkAddresses(witOracle.network);
		const target = at || addresses?.core[artifact] || addresses?.apps[artifact];
		if (!abis[artifact] || !target) {
			throw new Error(`EVM network ${witOracle.network} => unavailable framework appliance: ${artifact}`);
		}
		super({ artifact, network: witOracle.network, networkId: witOracle.networkId, target, runner: witOracle.runner });
		this.witOracle = witOracle;
	}

	/**
	 * Attach the contract wrapper to a different address.
	 * @param target New address to attach to.
	 * @returns The contract wrapper instance, connected to the new address.
	 */
	public async attach(target: string | Addressable): Promise<WitAppliance> {
		const contract = this._contract.attach(target);
		return contract.getFunction("witOracle()")
			.staticCall()
			.then((witOracleAddress) => {
				if (witOracleAddress.toLowerCase() !== this.witOracle.address.toString().toLowerCase()) {
					throw new Error(`${this.constructor.name}: Target address ${target} in EVM network ${this.witOracle.network} bound to a different WitOracle (${witOracleAddress}).`);
				} else {
					super.attach(target);
					return this;
				}
			})
			.catch((error) => {
				throw new Error(`${this.constructor.name}: Failed to attach to address ${target} in EVM network ${this.witOracle.network}: ${error.message}`);
			});
	}
}
