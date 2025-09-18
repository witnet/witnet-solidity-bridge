// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./Witnet.sol";

/// @title A library for encoding Witnet Data Requests.
/// @author The Witnet Foundation.
library WitOracleRadonEncodingLib {

    using WitnetBuffer for WitnetBuffer.Buffer;
    using WitnetCBOR for WitnetCBOR.CBOR;
    using WitnetCBOR for WitnetCBOR.CBOR[];

    bytes internal constant WITNET_RADON_OPCODES_RESULT_TYPES =
        hex"10ffffffffffffffffffffffffffffff040100010203050406071311ff0101ff07ff02ffffffffffffffffffffffffff070304ff04ffffffffffffff03ffffff0405070202ff0404040403ffffffffff05070402040205050505ff04ff04ffff07010203050406070101ff06ffff06ff0203050404000106060707070701ffff";
            // 10ffffffffffffffffffffffffffffff
            // 040100001203050406070100ff0101ff
            // 07ff02ffffffffffffffffffffffffff
            // 070304ff04ffffffffffffff03ffffff
            // 0405070202ff0404040403ffffffffff
            // 05070402040205050505ff04ff04ffff
            // 07010203050406070101ff06ffff06ff
            // 0203050404000106060707070701ffff

    error UnsupportedDataRequestMethod(uint8 method, string schema, string body, string[2][] headers);
    error UnsupportedRadonDataType(uint8 datatype, uint256 maxlength);
    error UnsupportedRadonFilterOpcode(uint8 opcode);
    error UnsupportedRadonFilterArgs(uint8 opcode, bytes args);
    error UnsupportedRadonReducerOpcode(uint8 opcode);
    error UnsupportedRadonReducerScript(uint8 opcode, bytes script, uint256 offset);
    error UnsupportedRadonScript(bytes script, uint256 offset);
    error UnsupportedRadonScriptOpcode(bytes script, uint256 cursor, uint8 opcode);
    error UnsupportedRadonTallyScript(bytes32 hash);

    /// ===============================================================================================================
    /// --- WitOracleRadonEncodingLib internal methods --------------------------------------------------------------------------------

    function size(Witnet.RadonDataTypes _type) internal pure returns (uint16) {
        if (_type == Witnet.RadonDataTypes.Integer
            || _type == Witnet.RadonDataTypes.Float
        ) {
            return 9;
        } else if (_type == Witnet.RadonDataTypes.Bool) {
            return 1;
        } else {
            // undetermined
            return 0; 
        }
    }


    /// ===============================================================================================================
    /// --- WitOracleRadonEncodingLib public methods (if used library will have to linked to calling contracts) -----------------------

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

    function encode(Witnet.RadonRetrieval memory source)
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
        if (source.radonScript.length > 0) {
            _encodedScript = abi.encodePacked(
                encode(uint64(source.radonScript.length), bytes1(0x1a)),
                source.radonScript
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
            _encodedHeaders
        );
    }

    function encode(
            Witnet.RadonRetrieval[] memory retrievals,
            string[] calldata args,
            bytes memory aggregatorInnerBytecode,
            bytes memory tallyInnerBytecode
        )
        public pure
        returns (bytes memory)
    {
        bytes[] memory encodedSources = new bytes[](retrievals.length);
        for (uint ix; ix < retrievals.length; ++ ix) {
            replaceWildcards(retrievals[ix], args);
            encodedSources[ix] = encode(retrievals[ix]);
        }
        return abi.encodePacked(
            WitnetBuffer.concat(encodedSources),
            encode(uint64(aggregatorInnerBytecode.length), bytes1(0x1a)),
            aggregatorInnerBytecode,
            encode(uint64(tallyInnerBytecode.length), bytes1(0x22)),
            tallyInnerBytecode
        );
    }
    
    function encode(
            Witnet.RadonRetrieval[] memory sources,
            string[][] memory args,
            bytes memory aggregatorInnerBytecode,
            bytes memory tallyInnerBytecode,
            uint16
        )
        public pure
        returns (bytes memory)
    {
        bytes[] memory encodedSources = new bytes[](sources.length);
        for (uint ix = 0; ix < sources.length; ix ++) {
            replaceWildcards(sources[ix], args[ix]);
            encodedSources[ix] = encode(sources[ix]);
        }
        return abi.encodePacked(
            WitnetBuffer.concat(encodedSources),
            encode(uint64(aggregatorInnerBytecode.length), bytes1(0x1a)),
            aggregatorInnerBytecode,
            encode(uint64(tallyInnerBytecode.length), bytes1(0x22)),
            tallyInnerBytecode
        );
    }

    function encode(Witnet.RadonReducer memory reducer)
        public pure
        returns (bytes memory bytecode)
    {
        // if (reducer.script.length == 0) {
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
        // } else {
        //     return abi.encodePacked(
        //         encode(uint64(reducer.script.length), bytes1(0x18)),
        //         reducer.script
        //     );
        // }
    }

    function encode(Witnet.RadonFilter memory filter)
        public pure
        returns (bytes memory bytecode)
    {        
        bytecode = abi.encodePacked(
            encode(uint64(filter.opcode), bytes1(0x08)),
            filter.cborArgs.length > 0
                ? abi.encodePacked(
                    encode(uint64(filter.cborArgs.length), bytes1(0x12)),
                    filter.cborArgs
                ) : bytes("")
        );
        return abi.encodePacked(
            encode(uint64(bytecode.length), bytes1(0x0a)),
            bytecode
        );
    }

    function encode(Witnet.RadonReduceOpcodes opcode)
        public pure
        returns (bytes memory)
    {
        
        return encode(uint64(opcode), bytes1(0x10));
    }

    function encode(Witnet.RadonSLAv1 memory sla)
        public pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            encode(uint64(sla.witnessReward), bytes1(0x10)),
            encode(uint64(sla.numWitnesses), bytes1(0x18)),
            encode(uint64(sla.minerCommitRevealFee), bytes1(0x20)),
            encode(uint64(sla.minConsensusPercentage), bytes1(0x28)),
            encode(uint64(sla.witnessCollateral), bytes1(0x30))
        );
    }

    function replaceCborStringsFromBytes(
            bytes memory data,
            uint8 argIndex,
            string memory argValue
        )
        public pure
        returns (bytes memory)
    {
        WitnetCBOR.CBOR memory cbor = WitnetCBOR.fromBytes(data);
        while (!cbor.eof()) {
            if (cbor.majorType == WitnetCBOR.MAJOR_TYPE_STRING) {
                _replaceCborWildcard(cbor, argIndex, argValue);
                cbor = cbor.settle();
            } else {
                cbor = cbor.skip().settle();
            }
        }
        return cbor.buffer.data;
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
                cbor = cbor.settle();
            } else {
                cbor = cbor.skip().settle();
            }
        }
        return cbor.buffer.data;
    }

    function replaceWildcards(Witnet.RadonRetrieval memory self, uint8 argIndex, string memory argValue)
        public pure
        returns (Witnet.RadonRetrieval memory)
    {
        self.url = WitnetBuffer.replace(self.url, argIndex, argValue);
        self.body = WitnetBuffer.replace(self.body, argIndex, argValue);
        self.radonScript = replaceCborStringsFromBytes(self.radonScript, argIndex, argValue);
        for (uint _ix = 0 ; _ix < self.headers.length; _ix ++) {
            self.headers[_ix][0] = WitnetBuffer.replace(self.headers[_ix][0], argIndex, argValue);
            self.headers[_ix][1] = WitnetBuffer.replace(self.headers[_ix][1], argIndex, argValue);
        }
        return self;
    }

    function replaceWildcards(Witnet.RadonRetrieval memory self, string[] memory args)
        public pure
        returns (Witnet.RadonRetrieval memory)
    {
        self.url = WitnetBuffer.replace(self.url, args);
        self.body = WitnetBuffer.replace(self.body, args);
        self.radonScript = replaceCborStringsFromBytes(self.radonScript, args);
        for (uint _ix = 0 ; _ix < self.headers.length; _ix ++) {
            self.headers[_ix][0] = WitnetBuffer.replace(self.headers[_ix][0], args);
            self.headers[_ix][1] = WitnetBuffer.replace(self.headers[_ix][1], args);
        }
        return self;
    }

    function validate(
            Witnet.RadonRetrievalMethods method,
            string memory url,
            string memory body,
            string[2][] memory headers,
            bytes memory script
        )
        public pure
        returns (bytes32)
    {
        if (!(
            method == Witnet.RadonRetrievalMethods.HttpPost
            || (method == Witnet.RadonRetrievalMethods.HttpGet && bytes(body).length == 0)
            || (method == Witnet.RadonRetrievalMethods.HttpHead && bytes(body).length == 0)
            || (method == Witnet.RadonRetrievalMethods.RNG
                && bytes(url).length == 0
                && bytes(body).length == 0
                && headers.length == 0
                && script.length >= 1
            )
        )) {
            revert UnsupportedDataRequestMethod(
                uint8(method),
                url,
                body,
                headers
            );
        }
        return keccak256(abi.encode(method, url, body, headers, script));
    }
    
    function validate(
            Witnet.RadonDataTypes dataType,
            uint16 maxDataSize
        )
        public pure
        returns (uint16)
    {
        if (
            dataType == Witnet.RadonDataTypes.Any
                || dataType == Witnet.RadonDataTypes.String
                || dataType == Witnet.RadonDataTypes.Bytes
                || dataType == Witnet.RadonDataTypes.Array
                || dataType == Witnet.RadonDataTypes.Map
        ) {
            if (maxDataSize == 0) {
                revert UnsupportedRadonDataType(
                    uint8(dataType),
                    maxDataSize
                );
            }
            return maxDataSize + 3; // todo?: determine CBOR-encoding length overhead??
        
        } else if (
            dataType == Witnet.RadonDataTypes.Integer
                || dataType == Witnet.RadonDataTypes.Float
                || dataType == Witnet.RadonDataTypes.Bool
        ) {
            return 9; 
        
        } else {
            revert UnsupportedRadonDataType(
                uint8(dataType),
                size(dataType)
            );
        }
    }

    function validate(Witnet.RadonFilter memory filter)
        public pure
    {
        if (
            filter.opcode == Witnet.RadonFilterOpcodes.StandardDeviation
        ) {
            // check filters that require arguments
            if (filter.cborArgs.length == 0) {
                revert UnsupportedRadonFilterArgs(uint8(filter.opcode), filter.cborArgs);
            }
        } else if (
            filter.opcode == Witnet.RadonFilterOpcodes.Mode
        ) {
            // check filters that don't require any arguments
            if (filter.cborArgs.length > 0) {
                revert UnsupportedRadonFilterArgs(uint8(filter.opcode), filter.cborArgs);
            }
        } else {
            // reject unsupported opcodes
            revert UnsupportedRadonFilterOpcode(uint8(filter.opcode));
        }
    }

    function validate(Witnet.RadonReducer memory reducer)
        public pure
    {
        // if (reducer.script.length == 0) {
            if (!(
                reducer.opcode == Witnet.RadonReduceOpcodes.AverageMean 
                    || reducer.opcode == Witnet.RadonReduceOpcodes.StandardDeviation
                    || reducer.opcode == Witnet.RadonReduceOpcodes.Mode
                    || reducer.opcode == Witnet.RadonReduceOpcodes.ConcatenateAndHash
                    || reducer.opcode == Witnet.RadonReduceOpcodes.AverageMedian
            )) {
                revert UnsupportedRadonReducerOpcode(uint8(reducer.opcode));
            }
            for (uint ix = 0; ix < reducer.filters.length; ix ++) {
                validate(reducer.filters[ix]);
            }
        // } else {
        //     if (uint8(reducer.opcode) != 0xff || reducer.filters.length > 0) {
        //         revert UnsupportedRadonReducerScript(
        //             uint8(reducer.opcode),
        //             reducer.script,
        //             0
        //         );
        //     }
        // }
    }

    function validate(Witnet.RadonSLAv1 memory sla)
        public pure
    {
        if (sla.witnessReward == 0) {
            revert("WitOracleRadonEncodingLib: invalid SLA: no reward");
        }
        if (sla.numWitnesses == 0) {
            revert("WitOracleRadonEncodingLib: invalid SLA: no witnesses");
        } else if (sla.numWitnesses > 127) {
            revert("WitOracleRadonEncodingLib: invalid SLA: too many witnesses (>127)");
        }
        if (
            sla.minConsensusPercentage < 51 
                || sla.minConsensusPercentage > 99
        ) {
            revert("WitOracleRadonEncodingLib: invalid SLA: consensus percentage out of range");
        }
        if (sla.witnessCollateral > 0) {
            revert("WitOracleRadonEncodingLib: invalid SLA: no collateral");
        }
        if (sla.witnessCollateral / sla.witnessReward > 127) {
            revert("WitOracleRadonEncodingLib: invalid SLA: collateral/reward ratio too high (>127)");
        }
    }

    function verifyRadonScriptResultDataType(bytes memory script)
        public pure
        returns (Witnet.RadonDataTypes)
    {
        return _verifyRadonScriptResultDataType(
            WitnetCBOR.fromBytes(script),
            false
        );
    }


    /// ===============================================================================================================
    /// --- WitOracleRadonEncodingLib private methods ---------------------------------------------------------------------------------

    function _replaceCborWildcard(
            WitnetCBOR.CBOR memory self,
            uint8 argIndex,
            string memory argValue
        ) private pure
    {
        uint _rewind = self.len;
        uint _start = self.buffer.cursor;
        bytes memory _peeks = bytes(self.readString());
        (bytes memory _pokes, uint _replacements) = WitnetBuffer.replace(_peeks, argIndex, argValue);
        if (_replacements > 0) {
            bytes memory _encodedPokes = encode(string(_pokes));
            self.buffer.cursor = _start - _rewind;
            self.buffer.mutate(
                _peeks.length + _rewind,
                _encodedPokes
            );
            self.buffer.cursor += _encodedPokes.length;
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
        (bytes memory _pokes, uint _replacements) = WitnetBuffer.replace(_peeks, args);
        if (_replacements > 0) {
            bytes memory _encodedPokes = encode(string(_pokes));
            self.buffer.cursor = _start - _rewind;
            self.buffer.mutate(
                _peeks.length + _rewind,
                _encodedPokes
            );
            self.buffer.cursor += _encodedPokes.length;
        }
    }
    
    function _verifyRadonScriptResultDataType(WitnetCBOR.CBOR memory self, bool flip)
        private pure
        returns (Witnet.RadonDataTypes)
    {
        if (self.majorType == WitnetCBOR.MAJOR_TYPE_ARRAY) {
            WitnetCBOR.CBOR[] memory items = self.readArray();
            if (items.length > 1) {
                return flip
                    ? _verifyRadonScriptResultDataType(items[0], false)
                    : _verifyRadonScriptResultDataType(items[items.length - 2], true)
                ;
            } else {
                return Witnet.RadonDataTypes.Any;
            }
        } else if (self.majorType == WitnetCBOR.MAJOR_TYPE_INT) {            
            uint cursor = self.buffer.cursor;
            uint opcode = self.readUint();
            uint8 dataType = (opcode > WITNET_RADON_OPCODES_RESULT_TYPES.length
                ? 0xff
                : uint8(WITNET_RADON_OPCODES_RESULT_TYPES[opcode])
            );
            if (dataType > uint8(type(Witnet.RadonDataTypes).max)) {
                revert UnsupportedRadonScriptOpcode(
                    self.buffer.data,
                    cursor,
                    uint8(opcode)
                );
            }
            return Witnet.RadonDataTypes(dataType);
        } else {
            revert WitnetCBOR.UnexpectedMajorType(
                WitnetCBOR.MAJOR_TYPE_INT,
                self.majorType
            );
        }
    }

}