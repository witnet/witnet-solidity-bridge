// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./WitnetLib.sol";
import "solidity-stringutils/src/strings.sol";

/// @title A library for decoding Witnet request results
/// @notice The library exposes functions to check the Witnet request success.
/// and retrieve Witnet results from CBOR values into solidity types.
/// @author The Witnet Foundation.
library WitnetEncodingLib {

    using strings for string;
    using strings for strings.slice;
    using WitnetBuffer for WitnetBuffer.Buffer;
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetCBOR for WitnetCBOR.CBOR[];

    bytes internal constant WITNET_RADON_OPCODES_RESULT_TYPES =
        hex"10ffffffffffffffffffffffffffffff0401ff010203050406071311ff01ffff07ff02ffffffffffffffffffffffffff0703ffffffffffffffffffffffffffff0405070202ff04040404ffffffffffff05070402040205050505ff04ff04ffffff010203050406070101ffffffffffff02ff050404000106060707ffffffffff";
            // 10ffffffffffffffffffffffffffffff
            // 0401ff000203050406070100ff01ffff
            // 07ff02ffffffffffffffffffffffffff
            // 0703ffffffffffffffffffffffffffff
            // 0405070202ff04040404ffffffffffff
            // 05070402040205050505ff04ff04ffff
            // ff010203050406070101ffffffffffff
            // 02ff050404000106060707ffffffffff

    bytes internal constant URL_HOST_XALPHAS_CHARS = 
        hex"000000000000000000000000000000000000000000000000000000000000000000ffff00ffffffffffffffff00ff0000ffffffffffffffffffff00ff00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff0000ff00ffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

    bytes internal constant URL_PATH_XALPHAS_CHARS = 
        hex"000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff0000ff00ffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

    bytes internal constant URL_QUERY_XALPHAS_CHARS = 
        hex"000000000000000000000000000000000000000000000000000000000000000000ffff00ffffffffffffffffffffffffffffffffffffffffffffffff00ff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff0000ff00ffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

    error UrlBadHostIpv4(string fqdn, string part);
    error UrlBadHostPort(string fqdn, string port);
    error UrlBadHostXalphas(string fqdn, string part);
    error UrlBadPathXalphas(string path, uint pos);
    error UrlBadQueryXalphas(string query, uint pos);

    /// ===============================================================================================================
    /// --- WitnetLib internal methods --------------------------------------------------------------------------------

    function size(WitnetV2.RadonDataTypes _type) internal pure returns (uint16) {
        if (_type == WitnetV2.RadonDataTypes.Integer
            || _type == WitnetV2.RadonDataTypes.Float
        ) {
            return 9;
        } else if (_type == WitnetV2.RadonDataTypes.Bool) {
            return 1;
        } else {
            // undetermined
            return 0; 
        }
    }


    /// ===============================================================================================================
    /// --- WitnetLib public methods (if used library will have to linked to calling contracts) -----------------------

    /// @notice Encode bytes array into given major type (UTF-8 not yet supported)
    /// @param buf Bytes array
    /// @return Marshaled bytes
    function encode(bytes memory buf, uint majorType)
        public pure
        returns (bytes memory)
    {
        uint len = buf.length;
        if (len < 23) {
            return abi.encodePacked(
                uint8((majorType << 5) | uint8(len)),
                buf
            );
        } else {
            uint8 buf0 = uint8((majorType << 5));
            bytes memory buf1;
            if (len <= 0xff) {
                buf0 |= 24;
                buf1 = abi.encodePacked(uint8(len));                
            } else if (len <= 0xffff) {
                buf0 |= 25;
                buf1 = abi.encodePacked(uint16(len));
            } else if (len <= 0xffffffff) {
                buf0 |= 26;
                buf1 = abi.encodePacked(uint32(len));
            } else {
                buf0 |= 27;
                buf1 = abi.encodePacked(uint64(len));
            }
            return abi.encodePacked(
                buf0,
                buf1,
                buf
            );
        }
    }

    /// @notice Encode bytes array.
    /// @param buf Bytes array
    /// @return Mashaled bytes
    function encode(bytes memory buf)
        public pure
        returns (bytes memory)
    {
        return encode(buf, WitnetCBOR.MAJOR_TYPE_BYTES);
    } 

    /// @notice Encode string array (UTF-8 not yet supported).
    /// @param str String bytes.
    /// @return Mashaled bytes
    function encode(string memory str)
        public pure
        returns (bytes memory)
    {
        return encode(bytes(str), WitnetCBOR.MAJOR_TYPE_STRING);
    }

    /// @dev Encode uint64 into tagged varint.
    /// @dev See https://developers.google.com/protocol-buffers/docs/encoding#varints.
    /// @param n Number
    /// @param t Tag
    /// @return buf Marshaled bytes
    function encode(uint64 n, bytes1 t)
        public pure
        returns (bytes memory buf)
    {
        unchecked {
            // Count the number of groups of 7 bits
            // We need this pre-processing step since Solidity doesn't allow dynamic memory resizing
            uint64 tmp = n;
            uint64 numBytes = 2;
            while (tmp > 0x7F) {
                tmp = tmp >> 7;
                numBytes += 1;
            }
            buf = new bytes(numBytes);
            tmp = n;
            buf[0] = t;
            for (uint64 i = 1; i < numBytes; i++) {
                // Set the first bit in the byte for each group of 7 bits
                buf[i] = bytes1(0x80 | uint8(tmp & 0x7F));
                tmp = tmp >> 7;
            }
            // Unset the first bit of the last byte
            buf[numBytes - 1] &= 0x7F;
        }
    }   

    function encode(WitnetV2.DataSource memory source)
        public pure
        returns (bytes memory)
    {
        bytes memory _encodedMethod = encode(uint64(source.method), bytes1(0x08));
        bytes memory _encodedUrl;
        if (bytes(source.url).length > 0) {
            _encodedUrl = abi.encodePacked(
                encode(uint64(bytes(source.url).length), bytes1(0x12)),
                bytes(source.url)
            );
        }
        bytes memory _encodedScript;
        if (source.script.length > 0) {
            _encodedScript = abi.encodePacked(
                encode(uint64(source.script.length), bytes1(0x1a)),
                source.script
            );
        }
        bytes memory _encodedBody;
        if (bytes(source.body).length > 0) {
            _encodedBody = abi.encodePacked(
                encode(uint64(bytes(source.body).length), bytes1(0x22)),
                bytes(source.body)
            );
        }
        bytes memory _encodedHeaders;
        if (source.headers.length > 0) {
            for (uint _ix = 0; _ix < source.headers.length; _ix ++) {
                bytes memory _headers = abi.encodePacked(
                    encode(uint64(bytes(source.headers[_ix][0]).length), bytes1(0x0a)),
                    bytes(source.headers[_ix][0]),
                    encode(uint64(bytes(source.headers[_ix][1]).length), bytes1(0x12)),
                    bytes(source.headers[_ix][1])
                );
                _encodedHeaders = abi.encodePacked(
                    _encodedHeaders,
                    encode(uint64(_headers.length), bytes1(0x2a)),
                    _headers
                );
            }
        }
        uint _innerSize = (
            _encodedMethod.length
                + _encodedUrl.length
                + _encodedScript.length
                + _encodedBody.length
                + _encodedHeaders.length
        );
        return abi.encodePacked(
            encode(uint64(_innerSize), bytes1(0x12)),
            _encodedMethod,
            _encodedUrl,
            _encodedScript,
            _encodedBody,
            _encodedHeaders,
            source.resultMinRank > 0 || source.resultMaxRank > 0
                ? abi.encodePacked(
                    encode(uint64(source.resultMinRank), bytes1(0x30)),
                    encode(uint64(source.resultMaxRank), bytes1(0x38))
                ) : bytes("")
        );
    }

    function encode(
            WitnetV2.DataSource[] memory sources,
            string[][] memory args,
            bytes memory aggregatorInnerBytecode,
            bytes memory tallyInnerBytecode,
            uint16 resultMaxSize
        )
        public pure
        returns (bytes memory bytecode)
    {
        bytes[] memory encodedSources = new bytes[](sources.length);
        for (uint ix = 0; ix < sources.length; ix ++) {
            replaceWildcards(sources[ix], args[ix]);
            encodedSources[ix] = encode(sources[ix]);
        }
        bytecode = abi.encodePacked(
            WitnetBuffer.concat(encodedSources),
            encode(uint64(aggregatorInnerBytecode.length), bytes1(0x1a)),
            aggregatorInnerBytecode,
            encode(uint64(tallyInnerBytecode.length), bytes1(0x22)),
            tallyInnerBytecode,
            (resultMaxSize > 0
                ? encode(uint64(resultMaxSize), 0x28)
                : bytes("")
            )
        );
        return abi.encodePacked(
            encode(uint64(bytecode.length), bytes1(0x0a)),
            bytecode
        );
    }

    function encode(WitnetV2.RadonReducer memory reducer)
        public pure
        returns (bytes memory bytecode)
    {
        if (reducer.script.length == 0) {
            for (uint ix = 0; ix < reducer.filters.length; ix ++) {
                bytecode = abi.encodePacked(
                    bytecode,
                    encode(reducer.filters[ix])
                );
            }
            bytecode = abi.encodePacked(
                bytecode,
                encode(reducer.opcode)
            );
        } else {
            return abi.encodePacked(
                encode(uint64(reducer.script.length), bytes1(0x18)),
                reducer.script
            );
        }
    }

    function encode(WitnetV2.RadonFilter memory filter)
        public pure
        returns (bytes memory bytecode)
    {        
        bytecode = abi.encodePacked(
            encode(uint64(filter.opcode), bytes1(0x08)),
            filter.args.length > 0
                ? abi.encodePacked(
                    encode(uint64(filter.args.length), bytes1(0x12)),
                    filter.args
                ) : bytes("")
        );
        return abi.encodePacked(
            encode(uint64(bytecode.length), bytes1(0x0a)),
            bytecode
        );
    }

    function encode(WitnetV2.RadonReducerOpcodes opcode)
        public pure
        returns (bytes memory)
    {
        
        return encode(uint64(opcode), bytes1(0x10));
    }

    function encode(WitnetV2.RadonSLA memory sla)
        public pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encode(uint64(sla.witnessReward), bytes1(0x10)),
            encode(uint64(sla.numWitnesses), bytes1(0x18)),
            encode(uint64(sla.commitRevealFee), bytes1(0x20)),
            encode(uint64(sla.minConsensusPercentage), bytes1(0x28)),
            encode(uint64(sla.collateral), bytes1(0x30))
        );
    }

    function replaceCborStringsFromBytes(
            bytes memory data,
            string[] memory args
        )
        public pure
        returns (bytes memory)
    {
        WitnetCBOR.CBOR memory cbor = WitnetCBOR.fromBytes(data);
        while (!cbor.eof()) {
            if (cbor.majorType == WitnetCBOR.MAJOR_TYPE_STRING) {
                _replaceCborWildcards(cbor, args);
            }
            cbor = cbor.skip().settle();
        }
        return cbor.buffer.data;
    }

    function replaceWildcards(WitnetV2.DataSource memory self, string[] memory args)
        public pure
    {
        self.url = string (WitnetBuffer.replace(bytes(self.url), args));
        self.body = string(WitnetBuffer.replace(bytes(self.body), args));
        self.script = replaceCborStringsFromBytes(self.script, args);
    }

    function validate(
            WitnetV2.DataRequestMethods method,
            uint16 resultMinRank,
            uint16 resultMaxRank,
            string memory schema,
            string memory host,
            string memory path,
            string memory query,
            string memory body,
            string[2][] memory headers,
            bytes memory script
        )
        public pure
    {
        if (!(
            (method == WitnetV2.DataRequestMethods.HttpGet || method == WitnetV2.DataRequestMethods.HttpPost)
                && bytes(host).length > 0
                && (
                    keccak256(bytes(schema)) == keccak256(bytes("https://")) 
                    || keccak256(bytes(schema)) == keccak256(bytes("http://"))
                )
            || method == WitnetV2.DataRequestMethods.Rng
                && bytes(schema).length == 0
                && bytes(host).length == 0
                && bytes(path).length == 0
                && bytes(query).length == 0
                && bytes(body).length == 0
                && headers.length == 0
                && script.length >= 1
        )) {
            revert WitnetV2.UnsupportedDataRequestMethod(
                uint8(method),
                schema,
                body,
                headers
            );
        }
        if (resultMinRank > resultMaxRank) {
            revert WitnetV2.UnsupportedDataRequestMinMaxRanks(
                uint8(method),
                resultMinRank,
                resultMaxRank
            );
        }
        // Cannot perform formal validation of url parts, as they
        // could templatized.
        // NOP: validateUrlHost(host);
        // NOP: validateUrlPath(path);
        // NOP: validateUrlQuery(query);
    }
    
    function validate(
            WitnetV2.RadonDataTypes dataType,
            uint16 maxDataSize
        )
        public pure
        returns (uint16)
    {
        if (
            dataType == WitnetV2.RadonDataTypes.Any
                || dataType == WitnetV2.RadonDataTypes.String
                || dataType == WitnetV2.RadonDataTypes.Bytes
                || dataType == WitnetV2.RadonDataTypes.Array
        ) {
            if (/*maxDataSize == 0 ||*/maxDataSize > 2048) {
                revert WitnetV2.UnsupportedRadonDataType(
                    uint8(dataType),
                    maxDataSize
                );
            }
            return maxDataSize;
        } else if (
            dataType == WitnetV2.RadonDataTypes.Integer
                || dataType == WitnetV2.RadonDataTypes.Float
                || dataType == WitnetV2.RadonDataTypes.Bool
        ) {
            return 0; // TBD: size(dataType);
        } else {
            revert WitnetV2.UnsupportedRadonDataType(
                uint8(dataType),
                size(dataType)
            );
        }
    }

    function validate(WitnetV2.RadonFilter memory filter)
        public pure
    {
        if (
            filter.opcode == WitnetV2.RadonFilterOpcodes.StandardDeviation
        ) {
            // check filters that require arguments
            if (filter.args.length == 0) {
                revert WitnetV2.RadonFilterMissingArgs(uint8(filter.opcode));
            }
        } else if (
            filter.opcode == WitnetV2.RadonFilterOpcodes.Mode
        ) {
            // check filters that don't require any arguments
            if (filter.args.length > 0) {
                revert WitnetV2.UnsupportedRadonFilterArgs(uint8(filter.opcode), filter.args);
            }
        } else {
            // reject unsupported opcodes
            revert WitnetV2.UnsupportedRadonFilterOpcode(uint8(filter.opcode));
        }
    }

    function validate(WitnetV2.RadonReducer memory reducer)
        public pure
    {
        if (reducer.script.length == 0) {
            if (!(
                reducer.opcode == WitnetV2.RadonReducerOpcodes.AverageMean 
                    || reducer.opcode == WitnetV2.RadonReducerOpcodes.StandardDeviation
                    || reducer.opcode == WitnetV2.RadonReducerOpcodes.Mode
                    || reducer.opcode == WitnetV2.RadonReducerOpcodes.ConcatenateAndHash
                    || reducer.opcode == WitnetV2.RadonReducerOpcodes.AverageMedian
            )) {
                revert WitnetV2.UnsupportedRadonReducerOpcode(uint8(reducer.opcode));
            }
            for (uint ix = 0; ix < reducer.filters.length; ix ++) {
                validate(reducer.filters[ix]);
            }
        } else {
            if (uint8(reducer.opcode) != 0xff || reducer.filters.length > 0) {
                revert WitnetV2.UnsupportedRadonReducerScript(
                    uint8(reducer.opcode),
                    reducer.script,
                    0
                );
            }
        }
    }

    function validate(WitnetV2.RadonSLA memory sla)
        public pure
    {
        if (sla.witnessReward == 0) {
            revert WitnetV2.RadonSlaNoReward();
        }
        if (sla.numWitnesses == 0) {
            revert WitnetV2.RadonSlaNoWitnesses();
        } else if (sla.numWitnesses > 127) {
            revert WitnetV2.RadonSlaTooManyWitnesses(sla.numWitnesses);
        }
        if (
            sla.minConsensusPercentage < 51 
                || sla.minConsensusPercentage > 99
        ) {
            revert WitnetV2.RadonSlaConsensusOutOfRange(sla.minConsensusPercentage);
        }
        if (sla.collateral < 10 ** 9) {
            revert WitnetV2.RadonSlaLowCollateral(sla.collateral);
        }
    }

    function validateUrlHost(string memory fqdn)
        public pure
    {
        unchecked {
            if (bytes(fqdn).length > 0) {  
                strings.slice memory slice = fqdn.toSlice();
                strings.slice memory host = slice.split(string(":").toSlice());
                if (!_checkUrlHostPort(slice.toString())) {
                    revert UrlBadHostPort(fqdn, slice.toString());
                }
                strings.slice memory delim = string(".").toSlice();
                string[] memory parts = new string[](host.count(delim) + 1);
                if (parts.length == 1) {
                    revert UrlBadHostXalphas(fqdn, fqdn);
                }
                for (uint ix = 0; ix < parts.length; ix ++) {
                    parts[ix] = host.split(delim).toString();
                    if (!_checkUrlHostXalphas(bytes(parts[ix]))) {
                        revert UrlBadHostXalphas(fqdn, parts[ix]);
                    }
                }
                if (parts.length == 4) {
                    bool _prevDigits = false;
                    for (uint ix = 4; ix > 0; ix --) {
                        if (_checkUrlHostIpv4(parts[ix - 1])) {
                            _prevDigits = true;
                        } else {
                            if (_prevDigits) {
                                revert UrlBadHostIpv4(fqdn, parts[ix - 1]);
                            } else {
                                break;
                            }
                        }   
                    }
                }
            }
        }
    }

    function validateUrlPath(string memory path)
        public pure
    {
        unchecked {
            if (bytes(path).length > 0) {
                if (bytes(path)[0] == bytes1("/")) {
                    revert UrlBadPathXalphas(path, 0);
                }
                for (uint ix = 0; ix < bytes(path).length; ix ++) {
                    if (URL_PATH_XALPHAS_CHARS[uint8(bytes(path)[ix])] == 0x0) {
                        revert UrlBadPathXalphas(path, ix);
                    }
                }
            }
        }
    }

    function validateUrlQuery(string memory query)
        public pure
    {
        unchecked {
            if (bytes(query).length > 0) {
                for (uint ix = 0; ix < bytes(query).length; ix ++) {
                    if (URL_QUERY_XALPHAS_CHARS[uint8(bytes(query)[ix])] == 0x0) {
                        revert UrlBadQueryXalphas(query, ix);
                    }
                }
            }
        }
    }

    function verifyRadonScriptResultDataType(bytes memory script)
        public pure
        returns (WitnetV2.RadonDataTypes)
    {
        return _verifyRadonScriptResultDataType(
            WitnetCBOR.fromBytes(script),
            false
        );
    }


    /// ===============================================================================================================
    /// --- WitnetLib private methods ---------------------------------------------------------------------------------

    function _checkUrlHostIpv4(string memory ipv4)
        private pure
        returns (bool)
    {
        (uint res, bool ok) = WitnetLib.tryUint(ipv4);
        return (ok && res <= 255);
    }

    function _checkUrlHostPort(string memory hostPort)
        private pure
        returns (bool)
    {
        (uint res, bool ok) = WitnetLib.tryUint(hostPort);
        return (ok && res <= 65536);
    }

    function _checkUrlHostXalphas(bytes memory xalphas)
        private pure
        returns (bool)
    {
        unchecked {
            for (uint ix = 0; ix < xalphas.length; ix ++) {
                if (URL_HOST_XALPHAS_CHARS[uint8(xalphas[ix])] == 0x00) {
                    return false;
                }
            }
            return true;
        }
    }

    function _replaceCborWildcards(
            WitnetCBOR.CBOR memory self,
            string[] memory args
        ) private pure
    {
        uint _rewind = self.len;
        uint _start = self.buffer.cursor;
        bytes memory _peeks = bytes(self.readString());
        uint _dataLength = _peeks.length + _rewind;
        bytes memory _pokes = WitnetBuffer.replace(_peeks, args);
        if (keccak256(_pokes) != keccak256(bytes(_peeks))) {
            self.buffer.cursor = _start - _rewind;
            self.buffer.mutate(
                _dataLength,
                encode(string(_pokes))
            );
        }
        self.buffer.cursor = _start;
    }

    // event Log(WitnetCBOR.CBOR self, bool flip);
    function _verifyRadonScriptResultDataType(WitnetCBOR.CBOR memory self, bool flip)
        private pure
        returns (WitnetV2.RadonDataTypes)
    {
        // emit Log(self, flip);
        if (self.majorType == WitnetCBOR.MAJOR_TYPE_ARRAY) {
            WitnetCBOR.CBOR[] memory items = self.readArray();
            if (items.length > 1) {
                return flip
                    ? _verifyRadonScriptResultDataType(items[0], false)
                    : _verifyRadonScriptResultDataType(items[items.length - 2], true)
                ;
            } else {
                return WitnetV2.RadonDataTypes.Any;
            }
        } else if (self.majorType == WitnetCBOR.MAJOR_TYPE_INT) {            
            uint cursor = self.buffer.cursor;
            uint opcode = self.readUint();
            uint8 dataType = (opcode > WITNET_RADON_OPCODES_RESULT_TYPES.length
                ? 0xff
                : uint8(WITNET_RADON_OPCODES_RESULT_TYPES[opcode])
            );
            if (dataType > uint8(type(WitnetV2.RadonDataTypes).max)) {
                revert WitnetV2.UnsupportedRadonScriptOpcode(
                    self.buffer.data,
                    cursor,
                    uint8(opcode)
                );
            }
            return WitnetV2.RadonDataTypes(dataType);
        } else {
            revert WitnetCBOR.UnexpectedMajorType(
                WitnetCBOR.MAJOR_TYPE_INT,
                self.majorType
            );
        }
    }

}