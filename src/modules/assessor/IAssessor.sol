// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {IComparableParameters} from "src/modules/IComparableParameters.sol";
import {Agreement} from "src/libraries/LibOrderBook.sol";

/**
 * Assessors are used to determine the cost a borrower must pay for a loan.
 * Each instance of an Assessor is permissionlessly deployed as an independent contract and represents one computation
 * method for assessing cost of a loan. Each type of Assessor may use an arbitrary set of parameters, which will be
 * set and stored per position.
 * Each implementation contract must implement the functionality of the standard Assessor Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 */

/*
 * Each Assessor clone is used to determine the cost of a loan.
 */
interface IAssessor is IComparableParameters {
    /// @notice Returns the cost of a loan beyond original assets, denoted in loan asset.
    function getCost(Agreement calldata agreement) external view returns (uint256);
}
