// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset} from "src/libraries/LibUtils.sol";

/**
 * Assessors are used to determine the cost a borrower must pay to the lender for a loan.
 *
 * Cost can be denoted in one of two different assets: the same ERC20 lent or ETH. This is a known restriction to
 * generalizability. However, it is a significant simplification wrt to sending arbitrary assets to user accounts
 * and offers notable gas reductions at position exit time as well.
 */

interface IAssessor {
    /// @notice Returns the cost of a loan (not including principle) and the asset it is denoted in.
    /// @dev Asset must be ETH or ERC20.
    function getCost(
        Agreement calldata agreement,
        uint256 currentAmount
    ) external view returns (Asset memory asset, uint256 amount);

    function canHandleAsset(Asset calldata asset, bytes calldata parameters) external view returns (bool);
}
