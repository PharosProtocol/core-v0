// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

/**
 * Oracles are implemented using the Minimal Proxy Contract standard (https://eips.ethereum.org/EIPS/eip-1167).
 * Each unique Implementation Contract represents one computation method for assessing value of assets.
 * Each clone represents different set of call parameters to the valuation Method, likely including which asset is being
 * valued.
 * Each Implementation Contract must implement the functionionality of the standard Oracle Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 */

/*
 * Each Oracle clone is used to determine the value of an asset.
 */
interface IOracle {
    // function getValue() external;
    function getValue(uint256 amount) external view returns (uint256);
}
