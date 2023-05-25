// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Asset} from "src/LibUtil.sol";

/**
 * Oracles are used to assess the value of assets.
 * Each Type of an Oracle is permissionlessly deployed as an independent contract and represents one computation
 * method for valuing assets. Each instance of an Oracle Type is defined by an arbitrary set of parameters.
 * Each Oracle Type implementation must implement the functionality of the standard Oracle Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 */

interface IOracle {
    /// @notice returns the USD value of an asset.
    /// @dev reverts if asset not compatible with parameters.
    function getValue(Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        view
        returns (uint256);
    /// @notice returns the amount of asset equivalent to the given USD value.
    /// @dev reverts if asset not compatible with parameters.
    function getAmount(Asset calldata asset, uint256 value, bytes calldata parameters)
        external
        view
        returns (uint256);
    function isCompatible(Asset calldata asset, bytes calldata parameters) external view returns (bool);
}
