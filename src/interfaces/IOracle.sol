// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Asset} from "src/libraries/LibUtils.sol";

/**
 * Oracles are used to assess the value of assets denoted in ETH.
 */

interface IOracle {
    /// @notice manipulation-resistant approximate ETH amount of equivalent value. Used to determine fill terms.
    function getResistantValue(uint256 amount, bytes calldata parameters) external view returns (uint256 ethAmount);

    /// @notice instantaneous ETH amount of equivalent value. Used to determine liquidations.
    /// @dev spot price used for liquidation check only.
    function getSpotValue(uint256 amount, bytes calldata parameters) external view returns (uint256 ethAmount);

    /// @notice instantaneous amount of asset equivalent to given eth amount.
    function getResistantAmount(uint256 ethAmount, bytes calldata parameters) external view returns (uint256);

    function canHandleAsset(Asset calldata asset, bytes calldata parameters) external view returns (bool);
}
