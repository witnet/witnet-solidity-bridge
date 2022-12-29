// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "truffle/Assert.sol";
import "../contracts/libs/WitnetEncodingLib.sol";

contract TestWitnetEncodingLib {

  using WitnetEncodingLib for string;

  // event Log(bytes data);
  // event Log(bytes data, uint256 length);

  function testEncodeTaggedVarint() external {
    bytes memory bytecode = WitnetEncodingLib.encode(10 ** 6, bytes1(0x10));
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"10c0843d"),
      "bad encode(uint64,bytes1)"
    );
  }

  function testEncodeString() external {
    bytes memory bytecode = WitnetEncodingLib.encode(string("witnet"));
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"667769746E6574"),
      "bad encode(string)"
    );
  }

  function testEncodeBytes() external {
    bytes memory bytecode = WitnetEncodingLib.encode(bytes("witnet"));
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"467769746E6574"),
      "bad encode(bytes)"
    );
  }

  function testEncodeRadonReducerOpcodes() external {
    bytes memory bytecode = WitnetEncodingLib.encode(
      WitnetV2.RadonReducerOpcodes.StandardDeviation
    );
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"1007"),
      "bad encode(WitnetV2.RadonReducerOpcodes)"
    );
  }

  function testEncodeRadonSLA() external {
    bytes memory bytecode = WitnetEncodingLib.encode(
      WitnetV2.RadonSLA({
        witnessReward: 1000000,
        numWitnesses: 10,
        commitRevealFee: 1000000,
        minConsensusPercentage: 51,
        collateral: 5000000
      })
    );
    // emit Log(bytecode);
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"10c0843d180a20c0843d283330c096b102"),
      "bad encode(WitnetV2.RadonSLA)"
    );
  }

  function testEncodeRadonReducer1Filter() external {
    WitnetV2.RadonReducer memory reducer;
    reducer.opcode = WitnetV2.RadonReducerOpcodes.Mode;
    reducer.filters = new WitnetV2.RadonFilter[](1);
    reducer.filters[0].opcode = WitnetV2.RadonFilterOpcodes.StandardDeviation;
    reducer.filters[0].args = hex"fa40200000";
    bytes memory bytecode = WitnetEncodingLib.encode(reducer);
    // emit Log(bytecode);
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"0a0908051205fa402000001002"),
      "bad encode(WitnetV2.RadonReducer)"
    );
  }

  function testEncodeDataSourceUrlOnly() external {
    WitnetV2.DataSource memory source;
    source.method = WitnetV2.DataRequestMethods.HttpGet;
    source.url = "https://data.messar.io/api/v1/assets/\\0\\/metrics/market-data?fields=market_data/price_\\1\\";
    source.script = hex"861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b";
    bytes memory bytecode = WitnetEncodingLib.encode(source);
    // emit Log(bytecode);
    Assert.equal(
      keccak256(bytecode),
      keccak256(hex"128b010801125968747470733a2f2f646174612e6d65737361722e696f2f6170692f76312f6173736574732f5c305c2f6d6574726963732f6d61726b65742d646174613f6669656c64733d6d61726b65745f646174612f70726963655f5c315c1a2c861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b"),
      "bad encode(WitnetV2.DataSource)"
    );
  }

  function testEncodeDataSourceUrlBodyHeaders() external {
    WitnetV2.DataSource memory source;
    source.method = WitnetV2.DataRequestMethods.HttpPost;
    source.url = "https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v3";
    source.body = "{\"query\":\"{pool(id:\\\"0xc2a856c3aff2110c1171b8f942256d40e980c726\\\"){token1Price}}\"}";
    source.headers = new string[2][](2);
    source.headers[0] = [ "user-agent", "witnet-rust" ];
    source.headers[1] = [ "content-type", "text/html; charset=utf-8" ];
    source.script = hex"861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b";
    bytes memory bytecode = WitnetEncodingLib.encode(source);
    // emit Log(bytecode);
    Assert.equal(
      keccak256(bytecode),
      keccak256(
        hex"1285020803123a68747470733a2f2f6170692e74686567726170682e636f6d2f7375626772617068732f6e616d652f756e69737761702f756e69737761702d76331a2c861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b22527b227175657279223a227b706f6f6c2869643a5c223078633261383536633361666632313130633131373162386639343232353664343065393830633732365c22297b746f6b656e3150726963657d7d227d2a190a0a757365722d6167656e74120b7769746e65742d727573742a280a0c636f6e74656e742d747970651218746578742f68746d6c3b20636861727365743d7574662d38"),
      "bad encode(WitnetV2.DataSource)"
    );
  }

  function testReplaceCborStringsFromBytes() external {
    bytes memory radon = hex"861877821866646461746182186664706F6F6C821864635C305C8218571A000F4240185B";
    // emit Log(radon, radon.length);
    string[] memory args = new string[](1);
    args[0] = "token1Price";
    bytes memory newradon = WitnetEncodingLib.replaceCborStringsFromBytes(radon, args);
    // emit Log(newradon, newradon.length);
    Assert.equal(
      keccak256(newradon),
      keccak256(hex'861877821866646461746182186664706F6F6C8218646B746F6B656E3150726963658218571A000F4240185B'),
      "not good :/"
    );    
  }

  function testValidateUrlHostOk1() external {
    WitnetEncodingLib.validateUrlHost("witnet.io");
  }

  function testValidateUrlHostOk2() external {
    WitnetEncodingLib.validateUrlHost("api.coinone.co.kr");
  }

  function testValidateUrlHostOk3() external {
    WitnetEncodingLib.validateUrlHost("api.coinone.co.kr:123");
  }

  function testValidateUrlHostOk4() external {
    WitnetEncodingLib.validateUrlHost("123.coinone.co.kr:123");
  }

  function testValidateUrlHostOk5() external {
    WitnetEncodingLib.validateUrlHost("8.8.8.255:123");
  }

  function testValidateUrlHostNok1() external {
    try WitnetEncodingLib.validateUrlHost("witnet") {
      revert ("'witnet' should not be valid");
    }
    catch (bytes memory reason) {
      if (bytes4(reason) != bytes4(keccak256(bytes("UrlBadHostXalphas(string,string)")))) {
        revert ("unexpected revert reason");
      }
    }
  }

  function testValidateUrlHostNok2() external {
    try WitnetEncodingLib.validateUrlHost("api/coinone/co/kr") {
      revert ("'api/coinone/co/kr' should not be valid");
    }
    catch (bytes memory reason) {
      if (bytes4(reason) != bytes4(keccak256(bytes("UrlBadHostXalphas(string,string)")))) {
        revert ("unexpected revert reason");
      }
    }
  }

  function testValidateUrlHostNok3() external {
    try WitnetEncodingLib.validateUrlHost("api.coinone.co.kr:65537") {
      revert ("'api.coinone.co.kr:65537' should not be valid");
    }
    catch (bytes memory reason) {
      if (bytes4(reason) != bytes4(keccak256(bytes("UrlBadHostPort(string,string)")))) {
        revert ("unexpected revert reason");
      }
    }
  }

  function testValidateUrlHostNok4() external {
    try WitnetEncodingLib.validateUrlHost("api.coinone.co.kr:123:65536") {
      revert ("'api.coinone.co.kr:123:65536' should not be valid");
    }
    catch (bytes memory reason) {
      if (bytes4(reason) != bytes4(keccak256(bytes("UrlBadHostPort(string,string)")))) {
        revert ("unexpected revert reason");
      }
    }
  }

  function testValidateUrlHostNok5() external {
    try WitnetEncodingLib.validateUrlHost("256.8.8.8:123") {
      revert("'256.8.8.8:123' should not be valid");
    } catch (bytes memory reason) {
      if (bytes4(reason) != bytes4(keccak256(bytes("UrlBadHostIpv4(string,string)")))) {
        revert ("unexpected revert reason");
      }
    }
  }

  function testValidateUrlPathOk1() external {
    WitnetEncodingLib.validateUrlPath("");
  }

  function testValidateUrlPathOk2() external {
    WitnetEncodingLib.validateUrlPath("open/api/v2/market/ticker");
  }

  function testValidateUrlPathOk3() external {
    WitnetEncodingLib.validateUrlPath("api/spot/v3/instruments/\\0\\-\\1\\/ticker");
  }

  function testValidateUrlPathOk4() external {
    WitnetEncodingLib.validateUrlPath("api/spot/v3/instruments/\\0\\-\\1\\/ticker#tag");
  }

  function testValidateUrlPathOk5() external {
    WitnetEncodingLib.validateUrlPath("gh/fawazahmed0/currency-api@1/latest/currencies/\\0\\.json");
  }    

  function testValidateUrlPathNok1() external {
    try WitnetEncodingLib.validateUrlPath("/") {
      revert("'/' should not be valid");
    } catch (bytes memory reason) {
      if (bytes4(reason) != bytes4(keccak256(bytes("UrlBadPathXalphas(string,uint256)")))) {
        revert ("unexpected revert reason");
      }
    }
  }

  function testValidateUrlPathNok2() external {
    try WitnetEncodingLib.validateUrlPath("?") {
      revert("'?' should not be valid");
    } catch (bytes memory reason) {
      if (bytes4(reason) != bytes4(keccak256(bytes("UrlBadPathXalphas(string,uint256)")))) {
        revert ("unexpected revert reason");
      }
    }
  }

  function testValidateUrlQueryOk1() external {
    WitnetEncodingLib.validateUrlQuery("chain=56");
  }

  function testValidateUrlQueryOk2() external {
    WitnetEncodingLib.validateUrlQuery("symbol=\\0\\\\1\\");
  }

  function testValidateUrlQueryOk3() external {
    WitnetEncodingLib.validateUrlQuery("fields=market_data/price_\\1\\");
  }

  function testValidateUrlQueryOk4() external {
    WitnetEncodingLib.validateUrlQuery("from=\\0\\&to=\\1\\&lang=es&format=json");
  }

  function testValidateUrlQueryNok1() external {
    try WitnetEncodingLib.validateUrlQuery("/?") {
      revert("'/?' should not be valid");
    } catch (bytes memory reason) {
      if (bytes4(reason) != bytes4(keccak256(bytes("UrlBadQueryXalphas(string,uint256)")))) {
        revert ("unexpected revert reason");
      }
    }
  }

  function testValidateUrlQueryNok2() external {
    try WitnetEncodingLib.validateUrlQuery("?") {
      revert("'?' should not be valid");
    } catch (bytes memory reason) {
      if (bytes4(reason) != bytes4(keccak256(bytes("UrlBadQueryXalphas(string,uint256)")))) {
        revert ("unexpected revert reason");
      }
    }
  }

  function testVerifyRadonScriptOk1() external {
    Assert.equal(
      uint(WitnetEncodingLib.verifyRadonScriptResultDataType(hex"861877821866646461746182186664706f6f6c8218646b746f6b656e3150726963658218571a000f4240185b")),
      uint(WitnetV2.RadonDataTypes.Integer),
      "unexpected result data type"
    );
  }

  function testVerifyRadonScriptOk2() external {
    Assert.equal(
      uint(WitnetEncodingLib.verifyRadonScriptResultDataType(hex"80")),
      uint(WitnetV2.RadonDataTypes.Any),
      "unexpected result data type"
    );
  }

  function testVerifyRadonScriptOk3() external {
    Assert.equal(
      uint(WitnetEncodingLib.verifyRadonScriptResultDataType(hex"8218778218676445746167")),
      uint(WitnetV2.RadonDataTypes.String),
      "unexpected result data type"
    );
  }

}