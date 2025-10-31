const { ethers, hre } = require("hardhat")

describe("TestWitnet", () => {
	let witnet

	before(async () => {
		witnet = await ethers.deployContract("TestWitnet")
	})

	beforeEach(async () => {
		await witnet.deleteData()
	})

	it("testNOP()", async () => {
		await witnet.testNOP()
	})

	it("testSSTORE()", async () => {
		await witnet.testSSTORE()
	})

	it("testSLOAD()", async () => {
		await witnet.testSLOAD()
	})

	it("writeRequestWithBytecodePacked()", async () => {
		await witnet.writeRequestWithBytecodePacked()
	})

	it("writeRequestWithBytecode()", async () => {
		await witnet.writeRequestWithBytecode()
	})

	it("readRequestWithBytecode()", async () => {
		await witnet.readRequestWithBytecode()
	})

	it("writeRequestWithRadonHashPacked()", async () => {
		await witnet.writeRequestWithRadonHashPacked()
	})

	it("writeRequestWithRadonHash()", async () => {
		await witnet.writeRequestWithRadonHash()
	})

	it("writeResponsePacked()", async () => {
		await witnet.writeResponsePacked()
	})

	it("writeResponse()", async () => {
		await witnet.writeResponse()
	})

	it("readResponse()", async () => {
		await witnet.readResponse()
	})

	it("writeQueryPacked()", async () => {
		await witnet.writeQueryPacked()
	})

	it("writeQueryUnpacked1()", async () => {
		await witnet.writeQueryUnpacked1()
	})

	it("writeQueryUnpacked2()", async () => {
		await witnet.writeQueryUnpacked2()
	})

	it("readQueryPacked()", async () => {
		await witnet.readQuery()
	})
})
