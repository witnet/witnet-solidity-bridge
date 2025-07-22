// SPDX-License-Identifier: MIT
// Stratonet Contracts (last updated v1.0.0) (utils/Bech32.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the Bech32 address generation
 */
library Bech32 {
    bytes constant ALPHABET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";
    bytes constant ALPHABET_REV = hex"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0fff0a1115141a1e0705ffffffffffffff1dff180d19090817ff12161f1b13ff010003100b1c0c0e060402ffffffffffff1dff180d19090817ff12161f1b13ff010003100b1c0c0e060402ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";

    // 0f <= 0: 48      | 30
    // 0a <= 2: 50      | 32
    // 11 <= 3: 51      | 33
    // 15 <= 4: 52      | 34
    // 14 <= 5: 53      | 35
    // 1a <= 6: 54      | 36
    // 1e <= 7: 55      | 37
    // 07 <= 8: 56      | 38
    // 05 <= 9: 57      | 39
    
    // 1d <= a: 97, 65  | 61, 41
    // 18 <= c: 99, 67  | 63, 43
    // 0d <= d: 100, 68 | 64, 44
    // 19 <= e: 101, 69 | 65, 45
    // 09 <= f: 102, 70 | 66, 46
    // 08 <= g: 103, 71 | 67, 47
    // 17 <= h: 104, 72 | 68, 48
    // 12 <= j: 106, 74 | 6A, 4A
    // 16 <= k: 107, 75 | 6B, 4B
    // 1f <= l: 108, 76 | 6C, 4C
    // 1b <= m: 109, 77 | 6D, 4D
    // 13 <= n: 110, 78 | 6E, 4E
    
    // 01 <= p: 112, 80 | 70, 50
    // 00 <= q: 113, 81 | 71, 51
    // 03 <= r: 114, 82 | 72, 52
    // 10 <= s: 115, 83 | 73, 53
    // 0b <= t: 116, 84 | 74, 54
    // 1c <= u: 117, 85 | 75, 55
    // 0c <= v: 118, 86 | 76, 56
    // 0e <= w: 119, 87 | 77, 57
    // 06 <= x: 120, 88 | 78, 58
    // 04 <= y: 121, 89 | 79, 59
    // 02 <= z: 122, 90 | 7A, 5A
    
    uint32 constant ENC_BECH32 = 1;
    uint32 constant ENC_BECH32M = 0x2bc830a3;


    function toBech32(
        address addr,
        string memory prefix
    ) internal pure returns (string memory) {
        return toBech32(abi.encodePacked(addr), prefix);
    }

    function toBech32(
        bytes memory data,
        string memory prefix
    ) internal pure returns (string memory) {
        bytes memory hrp = abi.encodePacked(prefix);
        bytes memory input = convertBits(data, 8, 5, true);
        return encode(hrp, input, ENC_BECH32);
    }

    function toBech32(
        address addr,
        string memory prefix,
        uint8 version
    ) internal pure returns (string memory) {
        return toBech32(abi.encodePacked(addr), prefix, version);
    }

    function toBech32(
        bytes memory data,
        string memory prefix,
        uint8 version
    ) internal pure returns (string memory) {
        bytes memory hrp = abi.encodePacked(prefix);
        bytes memory input = convertBits(data, 8, 5, true);
        uint32 enc = ENC_BECH32;
        if (version > 0) {
            enc = ENC_BECH32M;
        }
        bytes memory inputWithV = abi.encodePacked(bytes1(version), input);
        return encode(hrp, inputWithV, enc);
    }

    function fromBech32(
        string memory bechAddr
    ) internal pure returns (address) {
        (, uint8[] memory data) = decode(
            abi.encodePacked(bechAddr),
            ENC_BECH32
        );
        bytes memory input = convertBits(data, 5, 8, false);
        return getAddressFromBytes(input);
    }

    function fromBech32(
        string memory bechAddr,
        string memory prefix
    ) internal pure returns (address) {
        (bytes memory dHrp, uint8[] memory data) = decode(
            abi.encodePacked(bechAddr),
            ENC_BECH32
        );
        _requireHrpMatch(abi.encodePacked(prefix), dHrp);
        bytes memory input = convertBits(data, 5, 8, false);
        return getAddressFromBytes(input);
    }

    function fromBech32WithVersion(
        string memory bechAddr,
        string memory prefix,
        uint32 enc
    ) internal pure returns (uint8, bytes memory) {
        (bytes memory dHrp, uint8[] memory data) = decode(
            abi.encodePacked(bechAddr),
            enc
        );
        _requireHrpMatch(abi.encodePacked(prefix), dHrp);
        require(!(data.length < 1 || data[0] > 16), "Bech32: wrong version");
        uint8[] memory dataNoV = new uint8[](data.length - 1);
        for (uint8 i = 1; i < data.length; ++i) {
            dataNoV[i - 1] = data[i];
        }
        bytes memory input = convertBits(dataNoV, 5, 8, false);
        require(
            input.length >= 2 && input.length <= 40,
            "Bech32: wrong bits length"
        );
        require(
            !(data[0] == 0 && input.length != 20 && input.length != 32),
            "Bech32: wrong bits length for version"
        );
        return (uint8(data[0]), input);
    }

    function _requireHrpMatch(
        bytes memory hrp1,
        bytes memory hrp2
    ) internal pure {
        require(keccak256(hrp1) == keccak256(hrp2), "Bech32: hrp mismatch");
    }

    function getAddressFromBytes(
        bytes memory data
    ) internal pure returns (address) {
        require(data.length == 20, "Bech32: invalid data length");

        address addr;
        assembly {
            addr := mload(add(data, 20))
        }
        return addr;
    }

    function encode(
        bytes memory hrp,
        bytes memory input,
        uint32 enc
    ) internal pure returns (string memory) {
        unchecked {
            uint8[] memory checksum = createChecksum(hrp, input, enc);
            bytes memory result = new bytes(hrp.length + input.length + checksum.length + 1);
            for (uint i; i < hrp.length; ++ i) {
                result[i] = hrp[i];
            }
            result[hrp.length] = bytes1("1");
            uint offset = hrp.length + 1;
            for (uint i; i < input.length; ++ i) {
                uint8 _data = uint8(input[i]);
                if (_data < ALPHABET.length) {
                    result[i + offset] = ALPHABET[_data];
                }
            }
            offset += input.length;
            for (uint i; i < checksum.length; ++ i) {
                uint8 _data = uint8(checksum[i]);
                if (_data < ALPHABET.length) {
                    result[i + offset] = ALPHABET[_data];
                }
            }
            return string(result);
        }
    }

    function decode(bytes memory bechStr, uint32 enc) 
        internal pure 
        returns (bytes memory hrp, uint8[] memory data)
    {
        unchecked {
            uint pos;
            require(
                bechStr.length <= 90, 
                "Bech32: invalid string length"
            );
            for (uint p = 0; p < bechStr.length; ++ p) {
                uint8 charAt = uint8(bechStr[p]);
                require(
                    charAt >= 33 
                        && charAt <= 126, 
                    "Bech32: wrong char"
                );
                if (charAt == uint8(bytes1("1"))) {
                    require(
                        pos == 0 
                            && p >= 1 
                            && p + 7 <= bechStr.length, 
                        "Bech32: wrong pos of 1"
                    );
                    pos = p;
                }
            }
            hrp = new bytes(pos);
            for (uint i; i < pos; ++ i) {
                hrp[i] = bechStr[i]; 
            }
            data = new uint8[](bechStr.length - pos - 1);
            for (uint i; i < data.length; ++ i) {
                bytes1 charAt = ALPHABET_REV[uint8(bechStr[i + pos + 1])];
                require(charAt != 0xff, "Bech32: byte not in alphabet");
                data[i] = uint8(charAt);
            }
            require(
                verifyChecksum(hrp, data, enc), 
                "Bech32: wrong checksum"
            );
            uint dataLength = data.length - 6;
            assembly {
                mstore(data, dataLength)
            }
        }
    }

    function hrpExpand(
        bytes memory hrp
    ) internal pure returns (uint8[] memory ret) {
        unchecked {
            ret = new uint8[](hrp.length + hrp.length + 1);
            for (uint p; p < hrp.length; ++ p) {
                ret[p] = uint8(hrp[p]) >> 5;
                ret[p + hrp.length + 1] = uint8(hrp[p]) & 31;
            }
        }
    }

    function polymod(uint32[] memory values) internal pure returns (uint32) {
        uint32 chk = 1;
        uint32[5] memory GEN = [
            0x3b6a57b2,
            0x26508e6d,
            0x1ea119fa,
            0x3d4233dd,
            0x2a1462b3
        ];

        unchecked {
            for (uint32 i = 0; i < values.length; ++i) {
                uint32 top = chk >> 25;
                chk = (uint32(chk & 0x1ffffff) << 5) ^ uint32(values[i]);
                for (uint32 j = 0; j < 5; ++j) {
                    if (((top >> j) & 1) == 1) {
                        chk ^= GEN[j];
                    }
                }
            }
        }

        return chk;
    }

    function createChecksum(
        bytes memory hrp,
        bytes memory data,
        uint32 enc
    ) internal pure returns (uint8[] memory res) {
        unchecked {
            uint8[] memory values = hrpExpand(hrp);
            uint32[] memory comb = new uint32[](values.length + data.length + 6);

            for (uint i; i < values.length + data.length; ++ i) {
                if (i < values.length) {
                    comb[i] = uint32(values[i]);
                } else {
                    comb[i] = uint32(uint8(data[i - values.length]));
                }
            }
            
            res = new uint8[](6);
            uint32 mod = polymod(comb) ^ enc;
            for (uint p = 0; p < 6; ++ p) {
                res[p] = uint8((mod >> (5 * (5 - p))) & 31);
            }
        }
    }

    function verifyChecksum(
        bytes memory hrp,
        uint8[] memory data,
        uint32 enc
    ) internal pure returns (bool) {
        unchecked {
            uint8[] memory ehrp = hrpExpand(hrp);
            uint32[] memory cData = new uint32[](ehrp.length + data.length);
            for (uint i; i < ehrp.length; ++ i) {
                cData[i] = uint32(ehrp[i]);
            }
            for (uint i; i < data.length; ++ i) {
                cData[i + ehrp.length] = uint32(data[i]);
            }
            return polymod(cData) == enc;
        }
    }

    function convertBits(
        bytes memory data,
        uint frombits,
        uint tobits,
        bool pad
    ) internal pure returns (bytes memory) {
        uint8[] memory dataBits = new uint8[](data.length);

        for (uint32 p = 0; p < dataBits.length; ++p) {
            dataBits[p] = uint8(data[p]);
        }

        return _convertBits(dataBits, frombits, tobits, pad);
    }

    function convertBits(
        uint8[] memory data,
        uint frombits,
        uint tobits,
        bool pad
    ) internal pure returns (bytes memory) {
        return _convertBits(data, frombits, tobits, pad);
    }

    function _convertBits(
        uint8[] memory dataBits,
        uint frombits,
        uint tobits,
        bool pad
    ) internal pure returns (bytes memory ret) {
        uint acc = 0;
        uint bits = 0;

        uint maxv = (1 << tobits) - 1;

        unchecked {
            for (uint p; p < dataBits.length; ++p) {
                uint8 value = dataBits[p];
                require(
                    value >= 0 && (value >> frombits) == 0,
                    "Bech32: value must be non-negative and fit in frombits"
                );

                acc = (acc << frombits) | value;
                bits += frombits;

                while (bits >= tobits) {
                    bits -= tobits;
                    ret = abi.encodePacked(
                        ret,
                        bytes1(uint8((acc >> bits) & maxv))
                    );
                }
            }
        }

        if (pad) {
            if (bits > 0) {
                ret = abi.encodePacked(
                    ret,
                    bytes1(uint8((acc << (tobits - bits)) & maxv))
                );
            }
        } else {
            require(
                bits < frombits || ((acc << (tobits - bits)) & maxv) == 0,
                "Bech32: invalid padding or value size"
            );
        }
    }
}