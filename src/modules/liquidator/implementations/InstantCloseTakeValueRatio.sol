// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "src/libraries/C.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {InstantErc20} from "./InstantErc20.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

/*
 * Liquidate a position at kick time by giving closing the position and having position contract distribute loan and
 * collateral assets between liquidator, lender, and borrower. Only useable with ERC20s due to need for divisibility.
 * Liquidator reward is a ratio of loan value, and maximum is 100% of collateral assets.
 */

contract InstantCloseTakeValueRatio is InstantErc20 {
    struct Parameters {
        uint256 loanValueRatio;
    }

    constructor(address bookkeeperAddr) InstantErc20(bookkeeperAddr) {}

    function _receiveKick(address kicker, Agreement calldata agreement) internal override {
        _liquidate(kicker, agreement, true);
    }

    function getRewardCollAmount(Agreement memory agreement) public view override returns (uint256 rewardCollAmount) {
        Parameters memory params = abi.decode(agreement.liquidator.parameters, (Parameters));
        uint256 loanValue = IOracle(agreement.loanOracle.addr).getResistantValue(
            agreement.loanAmount,
            agreement.loanOracle.parameters
        );
        uint256 rewardValue = (loanValue * params.loanValueRatio) / C.RATIO_FACTOR;
        return IOracle(agreement.collOracle.addr).getResistantAmount(rewardValue, agreement.collOracle.parameters);
    }
}
