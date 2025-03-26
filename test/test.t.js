const { ethers, hre } = require("hardhat")

describe("TestWitnet", function () {
  
  let witnet;

  before(async function () {
    witnet = await ethers.deployContract("TestWitnet")
  });

  beforeEach(async function () {
    await witnet.deleteData()
  })

  it("testNOP()", async function () {
    await witnet.testNOP();
    // use the deployed contract
  });

  it("testSSTORE()", async function () {
    await witnet.testSSTORE();
    // use the deployed contract
  });

  it("testSLOAD()", async function () {
    await witnet.testSLOAD();
  });

  it("writeRequestWithBytecodePacked()", async function () {
    await witnet.writeRequestWithBytecodePacked();
  });

  it("writeRequestWithBytecode()", async function () {
    await witnet.writeRequestWithBytecode();
  });

  it("readRequestWithBytecode()", async function () {
    await witnet.readRequestWithBytecode();
  });

  it("writeRequestWithRadonHashPacked()", async function () {
    await witnet.writeRequestWithRadonHashPacked();
  });

  it("writeRequestWithRadonHash()", async function () {
    await witnet.writeRequestWithRadonHash();
  });

  it("writeResponsePacked()", async function () {
    await witnet.writeResponsePacked();
  });

  it("writeResponse()", async function () {
    await witnet.writeResponse();
  });

  it("readResponse()", async function () {
    await witnet.readResponse();
  });

  it("writeQueryPacked()", async function() {
    await witnet.writeQueryPacked();
  })

  it("writeQueryUnpacked1()", async function() {
    await witnet.writeQueryUnpacked1();
  })

  it("writeQueryUnpacked2()", async function() {
    await witnet.writeQueryUnpacked2();
  })

  it("readQuery()", async function () {
    await witnet.readQuery();
  });

});
