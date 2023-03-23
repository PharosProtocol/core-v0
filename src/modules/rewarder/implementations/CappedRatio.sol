// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {Agreement} from "src/libraries/LibOrderBook.sol";
import {IOracle} from "src/modules/oracle/IOracle.sol";
import {IRewarder} from "src/modules/rewarder/IRewarder.sol";

/*
 * Example Rewarder type that calculates reward as a ratio of *loan value*, with a minimum and maximum reward.
 */

struct Parameters {
    uint256 valueRatio;
    uint256 minRewardValue;
    uint256 maxRewardValue;
}

contract CappedRatio is IRewarder {
    uint256 private constant RATIO_BASE = 1e6; // NOTE what is a good scale to use for ratios? enough precision and less overflow

    /// @dev may return a number that is larger than the total collateral amount
    function getRewardValue(Agreement calldata agreement) external view returns (uint256) {
        Parameters memory p = abi.decode(agreement.rewarder.parameters, (Parameters));

        uint256 loanValue = IOracle(agreement.loanOracle.addr).getValue(
            agreement.loanAsset, agreement.loanAmount, agreement.loanOracle.parameters
        );
        uint256 baseRewardValue = loanValue * p.valueRatio / RATIO_BASE;
        // NOTE what if total collateral value < minRewardValue?
        if (baseRewardValue < p.minRewardValue) {
            return IOracle(agreement.loanOracle.addr).getAmount(
                agreement.loanAsset, p.minRewardValue, agreement.loanOracle.parameters
            );
        } else if (baseRewardValue > p.maxRewardValue) {
            return IOracle(agreement.loanOracle.addr).getAmount(
                agreement.loanAsset, p.maxRewardValue, agreement.loanOracle.parameters
            );
        } else {
            return IOracle(agreement.loanOracle.addr).getAmount(
                agreement.loanAsset, baseRewardValue, agreement.loanOracle.parameters
            );
        }
    }

    /// @notice returns true if reward for parameters 0 always greater than or equal to parameters 1
    function isGTE(bytes calldata parameters0, bytes calldata parameters1) external pure returns (bool) {
        Parameters memory p0 = abi.decode(parameters0, (Parameters));
        Parameters memory p1 = abi.decode(parameters1, (Parameters));
        return (
            p0.valueRatio >= p1.valueRatio && p0.minRewardValue >= p1.minRewardValue
                && p0.maxRewardValue >= p1.maxRewardValue
        );
    }

    function isLTE(bytes calldata parameters0, bytes calldata parameters1) external pure returns (bool) {
        Parameters memory p0 = abi.decode(parameters0, (Parameters));
        Parameters memory p1 = abi.decode(parameters1, (Parameters));
        return (
            p0.valueRatio <= p1.valueRatio && p0.minRewardValue <= p1.minRewardValue
                && p0.maxRewardValue <= p1.maxRewardValue
        );
    }
}