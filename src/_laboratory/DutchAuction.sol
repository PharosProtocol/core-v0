// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Liquidator} from "src/modules/liquidator/Liquidator.sol";

/**
 * AaveAssessor is one possible implementation of how a liquidator can be implemented to pool user assets.
 * This particular implementation uses a dutch auction mechanism to sell the position. Auction begins at kick time and
 * ends when a liquidator bids.
 */
abstract contract DutchAuction is Liquidator {}
