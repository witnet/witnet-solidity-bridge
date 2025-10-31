const { ethers, hre } = require("hardhat")

describe("TestBech32", () => {
	let bech32

	const witBytes20 = "0x28e6c01c921ec3dd2e4dedf0ba85b52dfb4fed86"

	const expectedWitMainnetPkh = "wit19rnvq8yjrmpa6tjdahct4pd49ha5lmvxuvddhv"
	const expectedWitTestnetPkh = "twit19rnvq8yjrmpa6tjdahct4pd49ha5lmvxjeyfha"

	// bytes20 public witBytes20 = hex"28e6c01c921ec3dd2e4dedf0ba85b52dfb4fed86";
	// bytes public witSignature = hex"";
	// address public evmAddress = 0x9634E8719f67b56a960B0A6C038adC437613842e;

	let witMainnetPkh, witTestnetPkh

	before(async () => {
		bech32 = await ethers.deployContract("TestBech32")
	})

	it("toBech32Mainnet()", async () => {
		await bech32.toBech32Mainnet(witBytes20)
		witMainnetPkh = await bech32.toBech32Mainnet.staticCall(witBytes20)
		console.log(witMainnetPkh)
	})

	it("toBech32Testnet()", async () => {
		await bech32.toBech32Testnet(witBytes20)
		witTestnetPkh = await bech32.toBech32Testnet.staticCall(witBytes20)
		console.log(witTestnetPkh)
	})

	it("fromBech32Mainnet(witMainnetPkh)", async () => {
		await bech32.fromBech32Mainnet(witMainnetPkh)
		console.log(await bech32.fromBech32Mainnet.staticCall(witMainnetPkh))
	})

	// it("fromBech32Mainnet(witTestnetPkh)", async function () {
	//   await bech32.fromBech32Mainnet(witTestnetPkh)
	//   console.log(await bech32.fromBech32Mainnet.staticCall(witTestnetPkh))
	// })

	it("fromBech32Testnet(witTestnetPkh)", async () => {
		await bech32.fromBech32Testnet(
			"twit1yyx8ll4ykyk0fugv3apefzlszlf8a9jxxr398l",
		) // (witTestnetPkh)
		console.log(await bech32.fromBech32Testnet.staticCall(witTestnetPkh))
	})

	// it("fromBech32Testnet(witMainnetPkh)", async function () {
	//   await bech32.fromBech32Testnet(witMainnetPkh)
	//   console.log(await bech32.fromBech32Testnet.staticCall(witMainnetPkh))
	// })

	it("parseHexAddress(hexAddr)", async () => {
		await bech32.parseHexAddress("34d903c72fC5A73Ef50817841d98F0e4019AF6B4")
		console.log(
			await bech32.parseHexAddress.staticCall(
				"34d903c72fC5A73Ef50817841d98F0e4019AF6B4",
			),
		)
	})
})
