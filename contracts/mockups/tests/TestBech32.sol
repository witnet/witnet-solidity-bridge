// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "../../libs/Bech32.sol";
import "../../libs/Witnet.sol";

contract TestBech32 {

    function toBech32Mainnet(bytes20 witBytes20) external returns (string memory) {
        return Bech32.toBech32(address(witBytes20), "wit");
    }

    function toBech32Testnet(bytes20 witBytes20) external returns (string memory) {
        return Bech32.toBech32(address(witBytes20), "twit");
    }

    function fromBech32Mainnet(string memory witPkh) external returns (address) {
        return Bech32.fromBech32(witPkh, "wit");
    }

    function fromBech32Testnet(string memory witPkh) external returns (address) {
        return Bech32.fromBech32(witPkh, "twit");
    }

    function parseHexAddress(string memory hexAddr) external returns (address) {
        return Witnet.toAddress(
            Witnet.parseHexString(hexAddr)
        );
    }
}