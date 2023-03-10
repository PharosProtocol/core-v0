// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {IParameterizedModule} from "src/modules/IParameterizedModule.sol";

/**
 * Rewarders are used to determine liquidator reward for a liquidation. Values are denoted in USDC values to enable
 * use across all assets and oracles.
 * Each instance of an Rewarder is permissionlessly deployed as an independent contract and represents one computation
 * method for assessing reward. Each type of Rewarder may use an arbitrary set of parameters, which will be
 * set per position.
 * Each implementation contract must implement the functionality of the standard Rewarder Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 */

/*
 * Each Rewarder is used to determine the reward paid to a liquidator.
 */
interface IRewarder is IParameterizedModule {
    /// @notice gets the *current* reward for liquidating a position
    function getRewardValue(address position, bytes calldata data) external view returns (uint256);
}
