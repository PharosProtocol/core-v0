// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {C} from "src/C.sol";
import {IComparableParameters} from "src/interfaces/IComparableParameters.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {Asset} from "src/LibUtil.sol";

/**
 * Liquidators are used to dismantle a kicked Position and return capital to Lender and Borrower. Liquidators will be
 * compensated based on the configuration of the Liquidator.
 * Liquidators are given a position by being set as the controller role over the position contract. This role is set
 * by the bookkeeper kick function.
 * Each implementation contract must implement the functionality of the standard Liquidator Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 */

interface ILiquidator is IComparableParameters {
    // NOTE it isn't really necessary to standardize the liquidation interface. It could entirely bypass modulus and
    //      implement an arbitrarily complex interface with calls being made directly to the liquidator contract. Would
    //      need to verify signatures, but otherwise not much more complex. Probably will not implement a liquidation
    //      UI for most implementations anyway.
    /// @notice liquidate an already-kicked position.
    function liquidate(Agreement memory agreement) external;

    // NOTE no need to make public or standard if using a liquidation contract/ Some liquidation systems, like an
    //      auction, will not have a clear set reward.
    /// @dev may return a number that is larger than the total collateral amount
    // function getRewardValue(Agreement calldata agreement) external view returns (uint256);

    function isCompatible(Asset calldata loanAsset, Asset calldata collAsset, bytes calldata parameters)
        external
        view
        returns (bool);
}