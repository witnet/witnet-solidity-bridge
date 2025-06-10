// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../contracts/libs/Witnet.sol";

contract TestWitnet {
    using Witnet for *;

    Witnet.Query internal query;
    Witnet.QueryRequest internal request;
    Witnet.QueryResponse internal response;

    uint256 internal __finalityBlock;

    constructor () {
        request = Witnet.QueryRequest({
            requester: address(0),
            callbackGas: 0,
            _0: 0,
            radonBytecode: hex"",
            radonHash: Witnet.RadonHash.wrap(0)
        });
    }

    function deleteData() external {
        delete request;
        delete response;
        delete query;
    }

    function testNOP() external {}

    function testSSTORE() external {
        __finalityBlock = block.number;
    }

    function testSLOAD() external {
        uint _finalityBlock = __finalityBlock;
        _finalityBlock ++;
    }

    function writeRequestWithBytecodePacked() external {
        request = Witnet.QueryRequest({
            requester: msg.sender,
            callbackGas: 500000,
            _0: 0,
            radonBytecode: hex"0aab0412520801123268747470733a2f2f6170692e62696e616e63652e55532f6170692f76332f7469636b65723f73796d626f6c3d4254435553441a1a841877821864696c61737450726963658218571a000f4240185b124d0801122c68747470733a2f2f6170692e62697466696e65782e636f6d2f76312f7075627469636b65722f6274637573641a1b8418778218646a6c6173745f70726963658218571a000f4240185b12480801122d68747470733a2f2f7777772e6269747374616d702e6e65742f6170692f76322f7469636b65722f6274637573641a15841877821864646c6173748218571a000f4240185b12550801123168747470733a2f2f6170692e626974747265782e636f6d2f76332f6d61726b6574732f4254432d5553442f7469636b65721a1e8418778218646d6c6173745472616465526174658218571a000f4240185b12620801123768747470733a2f2f6170692e636f696e626173652e636f6d2f76322f65786368616e67652d72617465733f63757272656e63793d4254431a258618778218666464617461821866657261746573821864635553448218571a000f4240185b12630801123268747470733a2f2f6170692e6b72616b656e2e636f6d2f302f7075626c69632f5469636b65723f706169723d4254435553441a2b87187782186666726573756c7482186668585842545a55534482186161618216008218571a000f4240185b1a0d0a0908051205fa3fc000001003220d0a0908051205fa4020000010031080a3c347180a2080ade20428333080acc7f037",
            radonHash: Witnet.RadonHash.wrap(0)
        });
    }

    function writeRequestWithBytecode() external {
        request.requester = msg.sender;
        request.callbackGas = 500000;
        request.radonBytecode = hex"0aab0412520801123268747470733a2f2f6170692e62696e616e63652e55532f6170692f76332f7469636b65723f73796d626f6c3d4254435553441a1a841877821864696c61737450726963658218571a000f4240185b124d0801122c68747470733a2f2f6170692e62697466696e65782e636f6d2f76312f7075627469636b65722f6274637573641a1b8418778218646a6c6173745f70726963658218571a000f4240185b12480801122d68747470733a2f2f7777772e6269747374616d702e6e65742f6170692f76322f7469636b65722f6274637573641a15841877821864646c6173748218571a000f4240185b12550801123168747470733a2f2f6170692e626974747265782e636f6d2f76332f6d61726b6574732f4254432d5553442f7469636b65721a1e8418778218646d6c6173745472616465526174658218571a000f4240185b12620801123768747470733a2f2f6170692e636f696e626173652e636f6d2f76322f65786368616e67652d72617465733f63757272656e63793d4254431a258618778218666464617461821866657261746573821864635553448218571a000f4240185b12630801123268747470733a2f2f6170692e6b72616b656e2e636f6d2f302f7075626c69632f5469636b65723f706169723d4254435553441a2b87187782186666726573756c7482186668585842545a55534482186161618216008218571a000f4240185b1a0d0a0908051205fa3fc000001003220d0a0908051205fa4020000010031080a3c347180a2080ade20428333080acc7f037";
    }

    function writeRequestWithRadonHashPacked() external {
        request = Witnet.QueryRequest({
            requester: msg.sender,
            callbackGas: 0, _0: 0,
            radonBytecode: new bytes(0),
            radonHash: Witnet.RadonHash.wrap(0x4377aca8710933b4b99a728bc566f27402c0339baf0f32960a3c6af720a1b7cc)
        });
    }

    function writeRequestWithRadonHash() external {
        request.requester = msg.sender;
        request.radonHash = Witnet.RadonHash.wrap(0x4377aca8710933b4b99a728bc566f27402c0339baf0f32960a3c6af720a1b7cc);
    }

    function readRequestWithBytecode() external returns (Witnet.QueryRequest memory) {
        return request;
    }

    function writeResponsePacked() external {
        response = Witnet.QueryResponse({
            reporter: msg.sender, 
            resultDrTxHash:  Witnet.TransactionHash.wrap(blockhash(block.number - 1)),
            resultTimestamp: Witnet.Timestamp.wrap(uint64(block.timestamp)),
            resultCborBytes: hex"d8278118ef",
            disputer: address(0), _0: uint32(0)
        });
    }

    function writeResponse() external {
        response.reporter = msg.sender;
        response.resultDrTxHash = Witnet.TransactionHash.wrap(blockhash(block.number - 1));
        response.resultTimestamp = Witnet.Timestamp.wrap(uint64(block.timestamp));
        response.resultCborBytes = hex"d8278118ef";
    }

    function readResponse() external returns (Witnet.QueryResponse memory) {
        return response;
    }

    function writeQueryPacked() external {
        ++ __finalityBlock;
        Witnet.QuerySLA memory _slaParams = Witnet.QuerySLA({
            witResultMaxSize: 34,
            witCommitteeSize: 16,
            witInclusionFees: 200000000
        });
        Witnet.QueryRequest memory _request = Witnet.QueryRequest({
            requester: msg.sender,
            callbackGas: 0, _0: 0,
            radonBytecode: new bytes(0),
            radonHash: Witnet.RadonHash.wrap(0x4377aca8710933b4b99a728bc566f27402c0339baf0f32960a3c6af720a1b7cc)
        });
        Witnet.QueryResponse memory _response = Witnet.QueryResponse({
            reporter: address(0),
            resultDrTxHash:  Witnet.TransactionHash.wrap(0),
            resultTimestamp: Witnet.Timestamp.wrap(0),
            resultCborBytes: new bytes(0),
            disputer: address(0), _0: uint32(0)
        });
        query = Witnet.Query({
            checkpoint: Witnet.BlockNumber.wrap(uint64(block.number)),
            hash: Witnet.QueryHash.wrap(0x010203040506070809101112131415),
            reward: Witnet.QueryEvmReward.wrap(1234567890123456),
            slaParams: _slaParams,
            request: _request,
            response: _response
        });
    }

    function writeQueryUnpacked1() external {
        ++ __finalityBlock;
        Witnet.QuerySLA memory _slaParams = Witnet.QuerySLA({
            witResultMaxSize: 34,
            witCommitteeSize: 16,
            witInclusionFees: 200000000
        });
        Witnet.QueryRequest memory _request = Witnet.QueryRequest({
            requester: msg.sender,
            callbackGas: 0, _0: 0,
            radonBytecode: new bytes(0),
            radonHash: Witnet.RadonHash.wrap(0x4377aca8710933b4b99a728bc566f27402c0339baf0f32960a3c6af720a1b7cc)
        });
        query.checkpoint = Witnet.BlockNumber.wrap(uint64(block.number));
        query.hash = Witnet.QueryHash.wrap(0x010203040506070809101112131415);
        query.reward = Witnet.QueryEvmReward.wrap(1234567890123456);
        query.slaParams = _slaParams;
        query.request = _request;
    }

    function writeQueryUnpacked2() external {
        ++ __finalityBlock;
        query.checkpoint = Witnet.BlockNumber.wrap(uint64(block.number));
        query.hash = Witnet.QueryHash.wrap(0x010203040506070809101112131415);
        query.reward = Witnet.QueryEvmReward.wrap(1234567890123456);
        query.slaParams.witResultMaxSize = 34;
        query.slaParams.witCommitteeSize = 16;
        query.slaParams.witInclusionFees = 200000000;
        query.request.requester = msg.sender;
        query.request.radonHash = Witnet.RadonHash.wrap(0x4377aca8710933b4b99a728bc566f27402c0339baf0f32960a3c6af720a1b7cc);
    }

    function readQuery() external returns (Witnet.Query memory) {
        return query;
    }

    // function testWitOracleQueryResponseUnpacking() external returns (Witnet.QueryResponse memory) {
    //     return __response;
    // }

}
