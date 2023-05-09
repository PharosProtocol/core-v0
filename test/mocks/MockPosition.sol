// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Asset} from "src/LibUtil.sol";
import {Position} from "src/terminal/IPosition.sol";

contract MockPosition is Position {
    uint256 currentAmount;

    constructor(uint256 amount) {
        currentAmount = amount;
    }

    function getExitAmount(Asset calldata, bytes calldata) external view override returns (uint256) {
        return currentAmount;
    }

    function _enter(Asset calldata, uint256, bytes calldata) internal pure override {
        return;
    }

    function _exit(Asset memory, bytes calldata) internal pure override returns (uint256) {
        return 0;
    }

    function _transferAsset(address payable to, Asset memory asset, uint256 amount) override internal {}
}
