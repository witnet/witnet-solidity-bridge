// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

interface Destructible {
    /// @dev Self-destruct the whole contract.
    function destruct() external;
}
