// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

struct TerminalCalldata {
    address asset;
    uint256 amount; // can amount safely be any smaller type?
    bytes parameters;
}
