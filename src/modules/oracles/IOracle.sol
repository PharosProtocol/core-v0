// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

/**
 * Oracles are used to assess the value of assets.
 * Each instance of an Oracle is permissionlessly deployed as an independent contract and represents one computation
 * method for valuing assets. Each type of Oracle may use an arbitrary set of parameters, which will be
 * set and stored per position.
 * Each implementation contract must implement the functionality of the standard Oracle Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 */

/*
 * Each Oracle clone is used to determine the value of an asset.
 */
interface IOracle {
    /// @notice require parameters to be valid and non-hostile.
    function verifyParameters(bytes calldata parameters) external view;
    /// @notice returns the USDC value of an asset.
    function getValue(uint256 amount, bytes calldata parameters) external view returns (uint256);
    /// @notice returns the amount of an asset equivalent to the given USDC value.
    function getAmount(uint256 value, bytes calldata parameters) external view returns (uint256);
}
