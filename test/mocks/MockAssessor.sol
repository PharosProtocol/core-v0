// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset} from "src/libraries/LibUtil.sol";
import {Assessor} from "src/modules/assessor/Assessor.sol";

contract MockAssessor is Assessor {
    uint256 finalCost;

    constructor(uint256 cost) {
        finalCost = cost;
    }

    function getCost(Agreement calldata, uint256) external view returns (uint256 amount) {
        return finalCost;
    }

    function canHandleAsset(Asset calldata, bytes calldata) external pure returns (bool) {
        return true;
    }
}
