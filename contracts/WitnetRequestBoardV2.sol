// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/V2/IWitnetBlocks.sol";
import "./interfaces/V2/IWitnetBytecodes.sol";
import "./interfaces/V2/IWitnetDecoder.sol";

// import "./interfaces/V2/IWitnetReporting.sol";
import "./interfaces/V2/IWitnetRequests.sol";
//import "./interfaces/V2/IWitnetTraps.sol";

/// @title Witnet Request Board V2 functionality base contract.
/// @author The Witnet Foundation.
abstract contract WitnetRequestBoardV2 is
    IWitnetRequests
    //, IWitnetReporting
    //, IWitnetTraps
{
    function blocks() virtual external view returns (IWitnetBlocks);
 
    function bytecodes() virtual external view returns (IWitnetBytecodes);
 
    function decoder() virtual external view returns (IWitnetDecoder);
}
