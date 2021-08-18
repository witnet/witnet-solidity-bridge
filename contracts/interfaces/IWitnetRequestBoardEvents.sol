// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

/// @title Witnet Request Board emitting events interface.
/// @author The Witnet Foundation.
interface IWitnetRequestBoardEvents {
    /// Emits when a new DR is posted
    event PostedRequest(uint256 id, address from);

    /// Emits when a result is reported
    event PostedResult(uint256 id, address from);

    /// Emits when a result is destroyed
    event DestroyedResult(uint256 id, address from);
}
