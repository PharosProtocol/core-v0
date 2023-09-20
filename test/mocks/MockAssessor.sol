// SPDX-License-Identifier: MIT
// solhint-disable

pragma solidity 0.8.19;

import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset} from "src/libraries/LibUtils.sol";
import {Assessor} from "src/plugins/assessor/Assessor.sol";

contract MockAssessor is Assessor {
    uint256 public finalCost;
    Asset public instanceAsset;

    constructor(Asset memory asset, uint256 cost) {
        instanceAsset = asset;
        finalCost = cost;
    }

    function _getCost(Agreement calldata, uint256) internal view override returns (Asset memory asset, uint256 amount) {
        return (instanceAsset, finalCost);
    }

    function canHandleAsset(Asset calldata, bytes calldata) external pure returns (bool) {
        return true;
    }
}
