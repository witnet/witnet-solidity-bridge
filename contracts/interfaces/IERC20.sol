// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /// Returns the amount of tokens in existence.
    function totalSupply() external view returns (uint256);

    /// Returns the amount of tokens owned by `_account`.
    function balanceOf(address _account) external view returns (uint256);

    /// Moves `_amount` tokens from the caller's account to `_recipient`.
    /// Returns a boolean value indicating whether the operation succeeded.
    /// Emits a {Transfer} event.
    function transfer(address _recipient, uint256 _amount) external returns (bool);

    /// Returns the remaining number of tokens that `_spender` will be
    /// allowed to spend on behalf of `_owner` through {transferFrom}. This is
    /// zero by default.
    /// This value changes when {approve} or {transferFrom} are called.
    function allowance(address _owner, address _spender) external view returns (uint256);

    /// Sets `_amount` as the allowance of `_spender` over the caller's tokens.
    /// Returns a boolean value indicating whether the operation succeeded.
    /// 
    /// IMPORTANT: Beware that changing an allowance with this method brings the risk
    /// that someone may use both the old and the new allowance by unfortunate
    /// transaction ordering. One possible solution to mitigate this race
    /// condition is to first reduce the spender's allowance to 0 and set the
    /// desired value afterwards:
    /// https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    ///
    /// Emits an {Approval} event.     
    function approve(address _spender, uint256 _amount) external returns (bool);

    /// Moves `amount` tokens from `_sender` to `_recipient` using the
    /// allowance mechanism. `amount` is then deducted from the caller's
    /// allowance.
    /// Returns a boolean value indicating whether the operation succeeded.
    /// Emits a {Transfer} event. 
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external returns (bool);

    /// Emitted when `value` tokens are moved from one account (`from`) to
    /// another (`to`).
    /// Note that `:value` may be zero.
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// Emitted when the allowance of a `spender` for an `owner` is set by
    /// a call to {approve}. `value` is the new allowance.
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
