// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./WitnetTypes.sol";

/**
 * @title Witnet Request Board querying interface.
 * @notice Sub-interface of a Witnet Request Board (WRB).
 * @dev It defines how to interact with the WRB in order to:
 * @dev - Read DR metadata.
 * @dev - Retrieve DR result, if any.
 * @author Witnet Foundation
 */
interface IWitnetQuery {
  /// @dev Retrieves the whole DR post record from the WRB.
  /// @param id The unique identifier of a previously posted data request.
  /// @return The DR record.
  function readDr(uint256 id) external view returns (WitnetTypes.DataRequest memory);

  /// @dev Retrieves bytecode of a previously posted DR.
  /// @param id The unique identifier of the data request.
  /// @return The DR bytecode.
  function readDrBytecode(uint256 id) external view returns (bytes memory);

  /// @dev Retrieves the gas price set for a previously posted DR.
  /// @param id The unique identifier of a previously posted DR.
  /// @return The latest gas price set by either the DR requestor, or upgrader.
  function readDrGasPrice(uint256 id) external view returns (uint256);

  /// @dev Retrieves Witnet tx hash of a previously solved DR.
  /// @param id The unique identifier of a previously posted data request.
  /// @return The hash of the DataRequest transaction in Witnet.
  function readDrTxHash(uint256 id) external view returns (uint256);

  /// @dev Retrieves the result (if already available) of one data request from the WRB.
  /// @param id The unique identifier of the data request.
  /// @return The result of the DR
  function readResult(uint256 id) external view returns (WitnetTypes.Result memory);

  /// @dev Returns the number of posted data requests in the WRB.
  /// @return The number of posted data requests in the WRB.
  function requestsCount() external view returns (uint256);
}
