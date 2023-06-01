// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {Asset} from "src/LibUtil.sol";

/**
 * Assessors are used to determine the cost a borrower must pay for a loan.
 * Cost is denoted in loan asset. This is a known restriction to generalizability. However, it is a significant
 * simplification wrt to sending arbitrary assets to user accounts and offers notable gas reductions in
 * factory exit implementations as well.
 */

interface IAssessor {
    /// @notice Returns the cost of a loan (not including principle), denoted in loan asset.
    function getCost(Agreement calldata agreement, uint256 currentAmount) external view returns (uint256 amount);
    function canHandleAsset(Asset calldata asset, bytes calldata parameters) external view returns (bool);
}
