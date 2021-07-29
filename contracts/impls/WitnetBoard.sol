// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "../interfaces/WitnetRequestBoardInterface.sol";
import "../utils/Proxiable.sol";

/**
 * @title Witnet Board functionality base contract.
 * @author Witnet Foundation
 **/
abstract contract WitnetBoard is
    Proxiable,
    WitnetRequestBoardInterface
{
    receive() external payable {
        revert("WitnetBoard: no ETH accepted");
    }
    fallback() external payable {
        revert("WitnetBoard: not implemented");
    }

    // ================================================================================================================
    // --- Overrides 'Proxiable' --------------------------------------------------------------------------------------

    /// @dev Gets immutable "heritage blood line" (ie. genotype) as a Proxiable, and eventually Upgradable, contract.
    /// @dev Should fail when trying to upgrade this contract to another one with a different `proxiableUUID()` value. 
    function proxiableUUID() external pure override returns (bytes32) {
        return (
            /* keccak256("io.witnet.proxiable.board") */
            0x9969c6aff411c5e5f0807500693e8f819ce88529615cfa6cab569b24788a1018
        );
    }   
}
