// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {C} from "src/libraries/C.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {IPosition} from "src/interfaces/IPosition.sol";

interface ILiquidator {
    function liquidate(address caller, Agreement calldata agreement) external;

}
