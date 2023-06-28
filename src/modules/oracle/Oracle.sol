// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {IOracle} from "src/interfaces/IOracle.sol";
import {Module} from "src/modules/Module.sol";
import {Asset} from "src/libraries/LibUtils.sol";

abstract contract Oracle is IOracle, Module {}
