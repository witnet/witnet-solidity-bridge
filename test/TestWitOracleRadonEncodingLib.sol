// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "truffle/Assert.sol";
import "../contracts/libs/WitOracleRadonEncodingLib.sol";

contract TestWitOracleRadonEncodingLib {

  using WitOracleRadonEncodingLib for string;

  // event Log(bytes data);
  // event Log(bytes data, uint256 length);

  function testEncodeTaggedVarint() external {
    bytes memory bytecode = WitOracleRadonEncodingLib.encode(10 ** 6, bytes1(0x10));
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"10c0843d"),
      "bad encode(uint64,bytes1)"
    );
  }

  function testEncodeString() external {
    bytes memory bytecode = WitOracleRadonEncodingLib.encode(string("witnet"));
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"667769746E6574"),
      "bad encode(string)"
    );
  }

  function testEncodeBytes() external {
    bytes memory bytecode = WitOracleRadonEncodingLib.encode(bytes("witnet"));
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"467769746E6574"),
      "bad encode(bytes)"
    );
  }

  function testEncodeRadonReducerOpcodes() external {
    bytes memory bytecode = WitOracleRadonEncodingLib.encode(
      Witnet.RadonReducerMethods.StandardDeviation
    );
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"1007"),
      "bad encode(Witnet.RadonReducerMethods)"
    );
  }

  function testEncodeRadonSLA() external {
    bytes memory bytecode = WitOracleRadonEncodingLib.encode(
      Witnet.RadonSLAv1({
        numWitnesses: 10,
        minConsensusPercentage: 51,
        minerCommitRevealFee: 1000000,
        witnessCollateral: 5000000,
        witnessReward: 1000000  
      })
    );
    // emit Log(bytecode);
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"10c0843d180a20c0843d283330c096b102"),
      "bad encode(Witnet.RadonSLAv1)"
    );
  }

  function testEncodeRadonReducer1Filter() external {
    Witnet.RadonReducer memory reducer;
    reducer.method = Witnet.RadonReducerMethods.Mode;
    reducer.filters = new Witnet.RadonFilter[](1);
    reducer.filters[0].method = Witnet.RadonFilterMethods.StandardDeviation;
    reducer.filters[0].cborArgs = hex"fa40200000";
    bytes memory bytecode = WitOracleRadonEncodingLib.encode(reducer);
    // emit Log(bytecode);
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"0a0908051205fa402000001002"),
      "bad encode(Witnet.RadonReducer)"
    );
  }

  function testEncodeRadonRetrievalUrlOnly() external {
    Witnet.RadonRetrieval memory source;
    source.method = Witnet.RadonRetrievalMethods.HttpGet;
    source.url = "https://data.messar.io/api/v1/assets/\\0\\/metrics/market-data?fields=market_data/price_\\1\\";
    source.radonScript = hex"861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b";
    bytes memory bytecode = WitOracleRadonEncodingLib.encode(source);
    // emit Log(bytecode);
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"128b010801125968747470733a2f2f646174612e6d65737361722e696f2f6170692f76312f6173736574732f5c305c2f6d6574726963732f6d61726b65742d646174613f6669656c64733d6d61726b65745f646174612f70726963655f5c315c1a2c861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b"),
      "bad encode(Witnet.RadonRetrieval)"
    );
  }

  function testEncodeRadonRetrievalUrlBodyHeaders() external {
    Witnet.RadonRetrieval memory source;
    source.method = Witnet.RadonRetrievalMethods.HttpPost;
    source.url = "https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v3";
    source.body = "{\"query\":\"{pool(id:\\\"0xc2a856c3aff2110c1171b8f942256d40e980c726\\\"){token1Price}}\"}";
    source.headers = new string[2][](2);
    source.headers[0] = [ "user-agent", "witnet-rust" ];
    source.headers[1] = [ "content-type", "text/html; charset=utf-8" ];
    source.radonScript = hex"861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b";
    bytes memory bytecode = WitOracleRadonEncodingLib.encode(source);
    // emit Log(bytecode);
    Assert.equal(
      keccak256(bytecode),
      keccak256(
        hex"1285020803123a68747470733a2f2f6170692e74686567726170682e636f6d2f7375626772617068732f6e616d652f756e69737761702f756e69737761702d76331a2c861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b22527b227175657279223a227b706f6f6c2869643a5c223078633261383536633361666632313130633131373162386639343232353664343065393830633732365c22297b746f6b656e3150726963657d7d227d2a190a0a757365722d6167656e74120b7769746e65742d727573742a280a0c636f6e74656e742d747970651218746578742f68746d6c3b20636861727365743d7574662d38"),
      "bad encode(Witnet.RadonRetrieval)"
    );
  }

  function testReplaceCborStringsFromBytes() external {
    bytes memory radon = hex"861877821866646461746182186664706F6F6C821864635C305C8218571A000F4240185B";
    // emit Log(radon, radon.length);
    string[] memory args = new string[](1);
    args[0] = "token1Price";
    bytes memory newradon = WitOracleRadonEncodingLib.replaceCborStringsFromBytes(radon, args);
    // emit Log(newradon, newradon.length);
    Assert.equal(
      keccak256(newradon),
      keccak256(hex'861877821866646461746182186664706F6F6C8218646B746F6B656E3150726963658218571A000F4240185B'),
      "not good :/"
    );    
  }

  function testReplaceCborStringsFromBytesByArgIndex() external {
    bytes memory radon = hex"861877821866646461746182186664706F6F6C821864635C305C8218571A000F4240185B";
    bytes memory newradon = WitOracleRadonEncodingLib.replaceCborStringsFromBytes(radon, 0, "token1Price");
    // emit Log(newradon, newradon.length);
    Assert.equal(
      keccak256(newradon),
      keccak256(hex'861877821866646461746182186664706F6F6C8218646B746F6B656E3150726963658218571A000F4240185B'),
      "not good :/"
    );    
  }

  function testReplaceCborStringsFromBytesByArgIndexInexistent() external {
    bytes memory radon = hex"861877821866646461746182186664706F6F6C821864635C305C8218571A000F4240185B";
    bytes memory newradon = WitOracleRadonEncodingLib.replaceCborStringsFromBytes(radon, 1, "token1Price");
    // emit Log(newradon, newradon.length);
    Assert.equal(
      keccak256(newradon),
      keccak256(hex'861877821866646461746182186664706F6F6C821864635C305C8218571A000F4240185B'),
      "not good :/"
    );    
  }

  function testVerifyRadonScriptOk1() external {
    Assert.equal(
      uint(WitOracleRadonEncodingLib.verifyRadonScriptResultDataType(hex"861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b")),
      uint(Witnet.RadonDataTypes.Integer),
      "unexpected result data type"
    );
  }

  function testVerifyRadonScriptOk2() external {
    Assert.equal(
      uint(WitOracleRadonEncodingLib.verifyRadonScriptResultDataType(hex"80")),
      uint(Witnet.RadonDataTypes.Any),
      "unexpected result data type"
    );
  }

  function testVerifyRadonScriptOk3() external {
    Assert.equal(
      uint(WitOracleRadonEncodingLib.verifyRadonScriptResultDataType(hex"8218778218676445746167")),
      uint(Witnet.RadonDataTypes.String),
      "unexpected result data type"
    );
  }

  function testVerifyRadonScriptOk4() external {
    Assert.equal(
      uint(WitOracleRadonEncodingLib.verifyRadonScriptResultDataType(hex"880B821866646461746182186165706169727382118282186762696483187582635C305CF5F4821818F48218646D746F6B656E5C315C50726963658218571A000F4240185B")),     
      uint(Witnet.RadonDataTypes.Integer),
      "unexpected result data type"
    );
  }

  function testVerifyRadonScriptOk5() external {
    Assert.equal(
      uint(WitOracleRadonEncodingLib.verifyRadonScriptResultDataType(hex"851876821182821867657469746c65831875a1635c315cf5f4821183821867696d65726765645f617418748218430082181800821867657374617465")),
      uint(Witnet.RadonDataTypes.String),
      "unexpected result data type"
    );
  }

}
