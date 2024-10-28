// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IWitFeedsEvents {
    
    /// A fresh update on the data feed identified as `erc2364Id4` has just been 
    /// requested and paid for by some `evmSender`, under command of the 
    /// `evmOrigin` externally owned account. 
    event PullingUpdate(
        address evmOrigin,
        address evmSender,
        bytes4  erc2362Id4,
        uint256 witOracleQueryId
    );
}
