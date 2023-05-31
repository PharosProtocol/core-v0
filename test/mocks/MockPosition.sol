// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Asset} from "src/LibUtil.sol";
import {Position} from "src/modules/position/Position.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";

contract MockPosition is Position {
    uint256 currentAmount;

    constructor(address bookkeeperAddr, uint256 amount) Position(bookkeeperAddr) {
        currentAmount = amount;
    }

    function getExitAmount(bytes calldata) external view override returns (uint256) {
        return currentAmount;
    }

    function _deploy(Asset calldata, uint256, bytes calldata) internal pure override {
        return;
    }

    function _exit(address, Agreement calldata, bytes calldata) internal pure override {
        return;
    }

    function canHandleAsset(Asset calldata, bytes calldata) external pure override returns (bool) {
        return true;
    }

    // function _transferLoanAsset(address payable to, Asset memory asset, uint256 amount) internal override {}
}
