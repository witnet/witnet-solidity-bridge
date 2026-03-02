import type { Witnet } from "@witnet/sdk";
import type { PriceFeedInfo } from "../types.js";
import { WitAppliance } from "./WitAppliance.js";
import type { WitOracle } from "./WitOracle.js";
import { AbiCoder, Addressable } from "ethers";

export class WitPriceFeedsLegacy extends WitAppliance {

	public static async fromWitOracle(witOracle: WitOracle, target?: string | Addressable): Promise<WitPriceFeedsLegacy> {
		const priceFeeds = new WitPriceFeedsLegacy({ witOracle, target });
		let priceFeedsWitOracleAddr;
		try {
			priceFeedsWitOracleAddr = await priceFeeds.contract.witOracle.staticCall();
		} catch {
			priceFeedsWitOracleAddr = await priceFeeds.provider
				.call({
					to: target,
					data: "0x46d1d21a", // funcSig for 'witnet()'
				})
				.then((result) => AbiCoder.defaultAbiCoder().decode(["address"], result))
				.then((result) => result.toString());
		}
		if (priceFeedsWitOracleAddr !== witOracle.address) {
			throw new Error(`${WitPriceFeedsLegacy.constructor.name} at ${target}: mismatching Wit/Oracle address (${priceFeedsWitOracleAddr})`);
		} else {
			return priceFeeds;
		}
	}

	protected constructor(specs: {
		witOracle: WitOracle, 
		target?: string | Addressable,
	}) {
		super({ ...specs, artifact: "WitPriceFeedsLegacy" });
	}

	public async getEvmFootprint(): Promise<string> {
		return this.contract.footprint.staticCall();
	}

	public async isCaptionSupported(caption: string): Promise<boolean> {
		return this.contract.supportsCaption.staticCall(caption);
	}

	public async lookupPriceFeedCaption(id4: Witnet.HexString): Promise<string> {
		return this.contract.lookupCaption.staticCall(id4);
	}

	public async lookupPriceFeedExponent(id4: Witnet.HexString): Promise<number> {
		return this.contract.lookupDecimals.staticCall(id4).then((result) => Number(result));
	}

	public async lookupPriceFeeds(): Promise<Array<PriceFeedInfo>> {
		const priceFeeds: Array<PriceFeedInfo> = await this.contract.supportedFeeds.staticCall().then((results) => {
			const [id4s, captions, dataSources] = results;
			return id4s.map((id4: string, index: number) => ({
				id4,
				exponent: -Number(captions[index].split("#")[0].split("-").slice(-1)[0]),
				symbol: captions[index],
				...(dataSources[index].endsWith("00000000000000")
					? {
							mapper: {
								class: "product",
								deps: [dataSources[index].slice(0, 42)],
							},
						}
					: {
							oracle: {
								class: "Witnet",
								target: this.witOracle.address,
								sources: dataSources[index],
							},
						}),
			}));
		});

		const latestPrices = await this.contract.latestPrices.staticCall(priceFeeds.map((pf) => pf.id4));

		return priceFeeds.map((pf, index) => ({
			...pf,
			lastUpdate: {
				timestamp: latestPrices[index].timestamp,
				trail: latestPrices[index].drTxHash,
				price: Number(latestPrices[index].value) / 10 ** -pf.exponent,
			},
		}));
	}
}
