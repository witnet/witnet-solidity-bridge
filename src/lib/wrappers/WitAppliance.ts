import type { Interface, InterfaceAbi } from "ethers";
import { ABIs } from "../../index.js";
import { getEvmNetworkAddresses } from "../utils.js";
import { ContractWrapper } from "./ContractWrapper.js";
import type { WitOracle } from "./WitOracle.js";

export abstract class WitAppliance extends ContractWrapper {
	public readonly witOracle: WitOracle;

	constructor(witOracle: WitOracle, artifact: string, at?: string) {
		const abis: Record<string, Interface | InterfaceAbi> = ABIs;
		const addresses = getEvmNetworkAddresses(witOracle.network);
		const target = at || addresses?.core[artifact] || addresses?.apps[artifact];
		if (!abis[artifact] || !target) {
			throw new Error(`EVM network ${witOracle.network} => artifact not available: ${artifact}`);
		}
		super(witOracle.signer, witOracle.network, abis[artifact], target);
		this.witOracle = witOracle;
	}
}
