// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

/**
 * Assessors are implemented using the Minimal Proxy Contract standard (https://eips.ethereum.org/EIPS/eip-1167).
 * Each unique Implementation Contract represents one computation method for assessing cost of a loan.
 * Each clone represents different set of call parameters to the assessing Method.
 * Each Implementation Contract must implement the functionionality of the standard Assessor Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 */

/*
 * Each Assessor clone is used to determine the cost of a loan.
 */
interface IAssessor {
    function getCost(address position) external view returns (uint256);
}
