// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "truffle/Assert.sol";
import "../contracts/libs/WitnetV2.sol";

contract TestWitnetV2 {
    using WitnetV2 for *;


    WitnetV2.Request internal __request;
    WitnetV2.Response internal __response;

    uint256 internal __finalityBlock;

    function testNOP() external {}

    function testSSTORE() external {
        __finalityBlock = block.number;
    }

    function testWitnetRequestPackingWithBytecode() external {
        __request = WitnetV2.Request({
            requester: msg.sender,
            gasCallback: 500000,
            evmReward: 10 ** 18,
            witnetBytecode: hex"0aab0412520801123268747470733a2f2f6170692e62696e616e63652e55532f6170692f76332f7469636b65723f73796d626f6c3d4254435553441a1a841877821864696c61737450726963658218571a000f4240185b124d0801122c68747470733a2f2f6170692e62697466696e65782e636f6d2f76312f7075627469636b65722f6274637573641a1b8418778218646a6c6173745f70726963658218571a000f4240185b12480801122d68747470733a2f2f7777772e6269747374616d702e6e65742f6170692f76322f7469636b65722f6274637573641a15841877821864646c6173748218571a000f4240185b12550801123168747470733a2f2f6170692e626974747265782e636f6d2f76332f6d61726b6574732f4254432d5553442f7469636b65721a1e8418778218646d6c6173745472616465526174658218571a000f4240185b12620801123768747470733a2f2f6170692e636f696e626173652e636f6d2f76322f65786368616e67652d72617465733f63757272656e63793d4254431a258618778218666464617461821866657261746573821864635553448218571a000f4240185b12630801123268747470733a2f2f6170692e6b72616b656e2e636f6d2f302f7075626c69632f5469636b65723f706169723d4254435553441a2b87187782186666726573756c7482186668585842545a55534482186161618216008218571a000f4240185b1a0d0a0908051205fa3fc000001003220d0a0908051205fa4020000010031080a3c347180a2080ade20428333080acc7f037",
            witnetRAD: bytes32(0),
            witnetSLA: WitnetV2.RadonSLA({
                committeeSize: 7,
                witnessingFeeNanoWit: 10 ** 9
            })
        });
    }

    function testWitnetRequestUnpackingWithBytecode() external returns (WitnetV2.Request memory) {
        return __request;
    }

    function testWitnetRequestPackingWithRadHash() external {
        __request = WitnetV2.Request({
            requester: msg.sender,
            gasCallback: 500000,
            evmReward: 10 ** 18,
            witnetBytecode: hex"",
            witnetRAD: bytes32(bytes2(0x1234)),
            witnetSLA: WitnetV2.RadonSLA({
                committeeSize: 7,
                witnessingFeeNanoWit: 10 ** 9
            })
        });
    }

    function testWitnetRequestUnpackingWithRadHash() external returns (WitnetV2.Request memory) {
        return __request;
    }

    function testWitnetResponsePacking() external {
        __response = WitnetV2.Response({
            reporter: msg.sender,
            finality: uint64(block.number),
            resultTimestamp: uint32(block.timestamp),
            resultTallyHash: blockhash(block.number - 1),
            resultCborBytes: hex"010203040506"
        });
    }

    function testWitnetResponseUnpacking() external returns (WitnetV2.Response memory) {
        return __response;
    }

}
