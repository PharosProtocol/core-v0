// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Oracle} from "src/modules/oracle/Oracle.sol";

/**
 * ChainLinkOracle is one possible implementation of how an oracle can be implemented to value assets.
 * This particular implementation uses chain link oracles to determine price.
 */
abstract contract ChainLinkOracle is Oracle {}
