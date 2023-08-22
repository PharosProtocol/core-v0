// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {Asset} from "src/libraries/LibUtils.sol";

/**
 * Liquidators are used to dismantle a kicked Position and return capital to Lender and Borrower. Liquidators will be
 * compensated based on the configuration of the Liquidator.
 * Liquidators are given a position by being set as the controller role over the position contract. This role is set
 * by the bookkeeper kick function.
 * Each implementation contract must implement the functionality of the standard Liquidator Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 *
 * It is not necessary to standardize the entire liquidation flow through this interface because the
 * liquidation logic will be executed by independent users, rather than the bookkeeper or other plugins. It is
 * possible to implement an arbitrarily complex interface with calls being made directly to the liquidator contract.
 */

interface ILiquidator {
    /// @notice handles receipt of a position that the bookkeeper has passed along for liquidation.
    /// @notice may also perform the actual liquidation.
    function receiveKick(address kicker, Agreement calldata agreement) external;
}
