// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "../interfaces/IERC20.sol";

abstract contract Payable {
    IERC20 public immutable currency;

    event Received(address from, uint256 amount);
    event Transfer(address to, uint256 amount);

    constructor(address _currency) {
        currency = IERC20(_currency);
    }

    /// Gets current transaction price.
    function _getGasPrice() internal view virtual returns (uint256);

    /// Gets current payment value.
    function _getMsgValue() internal view virtual returns (uint256);

    /// Perform safe transfer or whatever token is used for paying rewards.
    function _safeTransferTo(address payable, uint256) internal virtual;
}
