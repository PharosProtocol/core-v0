// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {IComparableParameters} from "src/modules/IComparableParameters.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {Asset} from "src/LibUtil.sol";

/**
 * Assessors are used to determine the cost a borrower must pay for a loan.
 * Cost is denoted in loan asset. This is a known restriction to generalizability. However, it is a significant
 * simplification wrt to sending arbitrary assets to user accounts and offers notable gas reductions in
 * terminal exit implementations as well.
 */

interface IAssessor is IComparableParameters {
    /// @notice Returns the cost of a loan (not including principle), denoted in loan asset.
    function getCost(Agreement calldata agreement) external view returns (uint256 amount);
}
