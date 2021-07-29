// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

interface Proxiable {
    function proxiableUUID() external pure returns (bytes32);
}
