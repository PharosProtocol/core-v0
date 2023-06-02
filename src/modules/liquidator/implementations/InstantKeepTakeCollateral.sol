// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {InstantErc20} from "./InstantErc20.sol";

/*
 * Liquidate a position at kick time by giving closing the position and having position contract distribute loan and 
 * collateral assets between liquidator, lender, and borrower. Only useable with ERC20s due to need for divisibility.
 * Liquidator reward is all of the collateral.
 */

contract InstantKeepTakeCollateral is InstantErc20 {
    // struct Parameters {}

    constructor(address bookkeeperAddr) InstantErc20(bookkeeperAddr) {}

    function _receiveKick(address kicker, Agreement calldata agreement) internal override {
        _liquidate(kicker, agreement, true);
    }

    function getRewardCollAmount(Agreement memory agreement) public pure override returns (uint256 rewardCollAmount) {
        return agreement.collAmount;
    }
}
