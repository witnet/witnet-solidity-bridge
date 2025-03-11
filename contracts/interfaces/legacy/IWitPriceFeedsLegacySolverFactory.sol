// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface IWitPriceFeedsLegacySolverFactory {
    event NewPriceFeedsSolver(address solver, bytes32 codehash, bytes constructorParams);
    function deployPriceSolver(bytes calldata initcode, bytes calldata additionalParams) external returns (address);
    function determinePriceSolverAddress(bytes calldata initcode, bytes calldata additionalParams) external view returns (address);
}