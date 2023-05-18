// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {IAssessor} from "src/interfaces/IAssessor.sol";
import {Module} from "src/modules/Module.sol";

abstract contract Assessor is IAssessor, Module {}
