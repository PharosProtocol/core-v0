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
    /// @dev reverts if asset not compatible with parameters.
    function getSpotValue(uint256 amount, bytes calldata parameters) external view returns (uint256 ethAmount);

    /// @notice instantaneous amount of asset equivalent to given eth amount.
    /// @dev reverts if asset not compatible with parameters.
    function getResistantAmount(uint256 ethAmount, bytes calldata parameters) external view returns (uint256);

    function canHandleAsset(Asset calldata asset, bytes calldata parameters) external view returns (bool);

    // // NOTE
    // // Is it possible to use arbitrary reference asset, as long as both oracles have the same reference asset?
    // function referenceAsset(bytes calldata parameters) external view returns (Asset memory asset);
}
