// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 * Oracles are used to assess the value of assets.
 * Each Type of an Oracle is permissionlessly deployed as an independent contract and represents one computation
 * method for valuing assets. Each instance of an Oracle Type is defined by an arbitrary set of parameters.
 * Each Oracle Type implementation must implement the functionality of the standard Oracle Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 */

interface IOracle {
    /// @notice require parameters to be valid and non-hostile.
    function verifyParameters(address asset, bytes calldata parameters) external view;
    /// @notice returns the USDC value of an asset.
    function getValue(uint256 amount, bytes calldata parameters) external view returns (uint256);
    /// @notice returns the amount of an asset equivalent to the given USDC value.
    function getAmount(uint256 value, bytes calldata parameters) external view returns (uint256);
}
