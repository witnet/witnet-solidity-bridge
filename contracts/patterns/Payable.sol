// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract Payable {
    IERC20 public immutable currency;

    event Received(address indexed from, uint256 value);
    event Transfer(address indexed to, uint256 value);

    constructor(address _currency) {
        currency = IERC20(_currency);
    }

    /// Gets current transaction price.
    function _getGasPrice() internal view virtual returns (uint256);

    /// Gets message actual sender.
    function _getMsgSender() internal view virtual returns (address);

    /// Gets current payment value.
    function _getMsgValue() internal view virtual returns (uint256);

    /// Perform safe transfer or whatever token is used for paying rewards.
    function __safeTransferTo(address payable, uint256) internal virtual;
}
