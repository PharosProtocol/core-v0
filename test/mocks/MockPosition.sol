// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Position} from "src/terminal/IPosition.sol";

contract MockPosition is Position {
    uint256 currentAmount;

    constructor(uint256 amount) {
        currentAmount = amount;
    }

    function getExitAmount(bytes calldata) external view override returns (uint256) {
        return currentAmount;
    }

    function _exit(bytes calldata) internal pure override returns (uint256) {
        return 0;
    }
}
