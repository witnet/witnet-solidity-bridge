// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

interface IWitnetAdminWhitelists {
  event ReportersSet(address[] reporters);
  event ReportersUnset(address[] reporters);
  function isReporter(address) external view returns (bool);
  function setReporters(address[] calldata reporters) external;
  function unsetReporters(address[] calldata reporters) external;
}
