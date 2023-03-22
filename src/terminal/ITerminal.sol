// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

interface ITerminal {
    function createPosition(address asset, uint256 amount, bytes memory parameters) external returns (address addr);
}
