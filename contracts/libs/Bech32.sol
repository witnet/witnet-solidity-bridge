// SPDX-License-Identifier: MIT
// Stratonet Contracts (last updated v1.0.0) (utils/Bech32.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the Bech32 address generation
 */
library Bech32 {
    bytes constant ALPHABET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";
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
        bool ok;
        for (uint8 i = 0; i < hrp1.length; i++) {
            if (hrp1[i] != hrp2[i]) {
                ok = true;
                break;
            }
        }
        require(!ok, "Bech32: hrp mismatch");
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

    function decode(
        bytes memory bechStr,
        uint32 enc
    ) internal pure returns (bytes memory, uint8[] memory) {
        require(bechStr.length <= 90, "Bech32: invalid bech length");

        bool hasLower;
        bool hasUpper;
        bool hasWChar;

        for (uint8 p = 0; p < bechStr.length; ++p) {
            uint8 charAt = uint8(bechStr[p]);
            if (charAt < 33 || charAt > 126) {
                hasWChar = true;
                break;
            }

            if (charAt >= 97 && charAt <= 122) {
                hasLower = true;
            }
            if (charAt >= 65 && charAt <= 90) {
                hasUpper = true;
            }
        }

        require(!hasWChar, "Bech32: wrong char");
        require(!(hasLower && hasUpper), "Bech32: no lower and upper bytes");
        bytes memory bechStrLower = toLowerCase(bechStr);
        int8 pos = lastIndexOf(bechStrLower, bytes1("1"));

        require(
            pos >= 1 && pos + 7 <= int8(uint8(bechStrLower.length)),
            "Bech32: wrong pos of 1"
        );

        uint8 upos = uint8(pos);

        bytes memory hrp = new bytes(upos);
        for (uint8 i = 0; i < upos; ++i) {
            hrp[i] = bechStrLower[i];
        }

        uint8[] memory data = new uint8[](bechStrLower.length - upos - 1);

        for (uint8 i = upos + 1; i < bechStrLower.length; ++i) {
            int8 apos = lastIndexOf(ALPHABET, bechStrLower[i]);
            require(apos != -1, "Bech32: byte not alphabet");
            data[i - upos - 1] = uint8(apos);
        }

        require(verifyChecksum(hrp, data, enc), "Bech32: wrong checksum");

        uint8[] memory dataNoCheck = new uint8[](data.length - 6);
        for (uint8 i = 0; i < dataNoCheck.length; ++i) {
            dataNoCheck[i] = data[i];
        }

        return (hrp, dataNoCheck);
    }

    function hrpExpand(
        bytes memory hrp
    ) internal pure returns (uint8[] memory ret) {
        unchecked {
            ret = new uint8[](hrp.length + hrp.length + 1);
            for (uint p; p < ret.length; ++ p) {
                if (p < hrp.length) {
                    ret[p] = uint8(hrp[p]) >> 5;
                } else if (p > hrp.length + 1) {
                    ret[p] = uint8(hrp[p - hrp.length - 1]) & 31;
                }
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

        for (uint32 i = 0; i < values.length; ++i) {
            uint32 top = chk >> 25;
            chk = (uint32(chk & 0x1ffffff) << 5) ^ uint32(values[i]);
            for (uint32 j = 0; j < 5; ++j) {
                if (((top >> j) & 1) == 1) {
                    chk ^= GEN[j];
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
        uint8[] memory ehrp = hrpExpand(hrp);
        uint32[] memory cData = new uint32[](ehrp.length + data.length);

        for (uint8 i = 0; i < ehrp.length; ++i) {
            cData[i] = uint32(ehrp[i]);
        }
        for (uint8 i = 0; i < data.length; ++i) {
            cData[i + ehrp.length] = uint32(data[i]);
        }

        return polymod(cData) == enc;
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