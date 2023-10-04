// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;


import {C} from "src/libraries/C.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";

interface ILiquidator {
    function getReward(Agreement calldata agreement
    ) external view returns ( uint256 amount);

}
