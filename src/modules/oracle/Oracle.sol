// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IOracle} from "src/interfaces/IOracle.sol";
import {Asset} from "src/libraries/LibUtils.sol";

abstract contract Oracle is IOracle {}
