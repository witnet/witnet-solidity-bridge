// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../WitnetRequestBoard.sol";
import "../utils/Proxiable.sol";

/**
 * @title Witnet Board base contract, with a Proxiable touch.
 * @author Witnet Foundation
 **/
abstract contract WitnetRequestBoardProxiableBase
    is
        Proxiable,
        WitnetRequestBoard
{
    // ================================================================================================================
    // --- Overrides 'Proxiable' --------------------------------------------------------------------------------------

    /// @dev Gets immutable "heritage blood line" (ie. genotype) as a Proxiable, and eventually Upgradable, contract.
    ///      If implemented as an Upgradable touch, upgrading this contract to another one with a different 
    ///      `proxiableUUID()` value should fail.
    function proxiableUUID() external pure override returns (bytes32) {
        return (
            /* keccak256("io.witnet.proxiable.board") */
            0x9969c6aff411c5e5f0807500693e8f819ce88529615cfa6cab569b24788a1018
        );
    }   
}
