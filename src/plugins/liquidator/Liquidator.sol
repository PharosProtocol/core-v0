// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ILiquidator} from "src/interfaces/ILiquidator.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";

abstract contract Liquidator is ILiquidator {
    function getReward(
        Agreement calldata agreement
    ) external view returns (uint256 amount) {
        (amount) = _getReward(agreement);
        
    }

    function _getReward(
        Agreement calldata agreement
    ) internal view virtual returns (uint256 amount);
}
