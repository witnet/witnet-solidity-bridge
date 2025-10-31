const assert = require("nanoassert")
const { utils } = require("eth-helpers")
const keccak = require("sha3-wasm").keccak256

const prefix = Buffer.from([0xff])

/**
 * Generate Ethereum CREATE2 address
 *
 * @param   {string|Buffer} address  Ethereum address of creator contract as
 *                                   string or as a 20 byte `Buffer`
 * @param   {string|Buffer} salt     256 bit salt as either string or 32 byte `Buffer`
 * @param   {string|Buffer} initCode init_code as string or Buffer
 * @returns {string}                 result address as hex encoded string. Not
 *                                   checksum'ed. This can be done with
 *                                   `eth-checksum` or similar modules
 */
module.exports = function create2(address, salt, initCode) {
	if (typeof address === "string") address = utils.parse.address(address)
	if (typeof salt === "string") salt = utils.parse.uint256(salt)
	if (typeof initCode === "string") initCode = utils.parse.bytes(initCode)

	assert(address.byteLength === 20, "address must be 20 bytes")
	assert(salt.byteLength === 32, "salt must be 32 bytes")
	assert(initCode.byteLength != null, "initCode must be Buffer")

	const codeHash = keccak().update(initCode).digest()

	return utils.format.address(
		keccak()
			.update(prefix)
			.update(address)
			.update(salt)
			.update(codeHash)
			.digest()
			.slice(-20),
	)
}
