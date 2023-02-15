// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

struct Position {
    bytes32 supplyAccountId;
    bytes32 borrowAccountId;
    bytes32 termSheetId;
    address terminalAddress;
    uint256 initLoanValue;
    uint256 openTime;
}
// ....