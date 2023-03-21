// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

/*
 * Each Position represents one deployment of capital through a Terminal.
 */
interface IPosition {
    function getValue(bytes calldata parameters) external view returns (uint256);
    function exit(bytes calldata parameters) external returns (uint256);
}
