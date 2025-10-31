const assert = require("nanoassert")
const { utils } = require("eth-helpers")
const keccak = require("sha3-wasm").keccak256

const factoryPrefix = Buffer.from([0xff])

/**
 * Generate Ethereum CREATE3-library address
 *
 * @param   {string|Buffer} address  Ethereum address of creator contract as
 *                                   string or as a 20 byte `Buffer`
 * @param   {string|Buffer} salt     256 bit salt as either string or 32 byte `Buffer`
 * @returns {string}                 result address as hex encoded string. Not
 *                                   checksum'ed. This can be done with
 *                                   `eth-checksum` or similar modules
 */
module.exports = function create3(address, salt) {
	if (typeof address === "string") address = utils.parse.address(address)
	if (typeof salt === "string") salt = utils.parse.uint256(salt)

	assert(address.byteLength === 20, "address must be 20 bytes")
	assert(salt.byteLength === 32, "salt must be 32 bytes")

	const factoryHash = utils.parse.uint256(
		"0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f",
	)
	const factoryAddr = keccak()
		.update(factoryPrefix)
		.update(address)
		.update(salt)
		.update(factoryHash)
		.digest()
		.slice(-20)

	assert(factoryAddr.byteLength === 20, "address must be 20 bytes")

	return utils.format.address(
		keccak()
			.update(Buffer.from([0xd6, 0x94]))
			.update(factoryAddr)
			.update(Buffer.from([0x01]))
			.digest()
			.slice(-20),
	)
}
