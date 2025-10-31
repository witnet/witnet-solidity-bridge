const { ethers, hre } = require("hardhat")

describe("TestSecp256k1", () => {
	let secp256k1

	const evmAddress = "0x9634E8719f67b56a960B0A6C038adC437613842e"
	const _evmDigest =
		"0xb2bfab80e07261eaed5f0d7946612dcc5d7c71eaaa959fc761f19d0b31275a24"
	const _witAddress = "0x28e6c01c921ec3dd2e4dedf0ba85b52dfb4fed86"
	const witSignature =
		"0x30dd7c53e23e6bb1367fe8a47e445eb7f6cece828287a4bbe2191f8ee64ee4615a0f333ea2c4c6e30bc1d9bf11b2d63c266668b7534c3480cf42c200557a17f31c"

	let _witMainnetPkh, _witTestnetPkh

	before(async () => {
		secp256k1 = await ethers.deployContract("TestSecp256k1")
	})

	it("recoverWitPublicKey()", async () => {
		console.log(await secp256k1.recoverWitPublicKeyX(witSignature, evmAddress))
	})

	it("recoverWitAddress()", async () => {
		console.log(await secp256k1.recoverWitAddr(witSignature, evmAddress))
	})
})
