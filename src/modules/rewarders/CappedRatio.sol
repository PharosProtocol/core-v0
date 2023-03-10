// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {IOracle} from "src/modules/IOracle.sol";
import {IRewarder} from "src/modules/IRewarder.sol";

/*
 * Example Rewarder type that calculates reward as a ratio of *loan value*, with a minimum and maximum reward.
 */
interface IStandardAssessor is IRewarder {
    function decodeParameters(bytes calldata parameters)
        external
        view
        returns (uint256 valueRatio, uint256 minRewardValue, uint256 maxRewardValue);
}

contract StandardAssessor is IStandardAssessor {
    uint256 private constant RATIO_BASE = 1e6; // what is a good scale to use for ratios? enough precision and less overflow

    function decodeParameters(bytes calldata parameters) public pure returns (uint256, uint256, uint256) {
        return abi.decode(parameters, (uint256, uint256, uint256));
    }

    /// @dev may return a number that is larger than the total collateral amount
    function getRewardValue(address position, bytes calldata data) external view returns (uint256) {
        (uint256 valueRatio, uint256 minRewardValue, uint256 maxRewardValue) = decodeParameters(data);
        uint256 loanValue = IOracle(position.loanOracle).getValue(position.LoanAmount);
        uint256 baseRewardValue = loanValue * valueRatio / RATIO_BASE;
        // NOTE what if total collateral value < minRewardValue?
        if (baseRewardValue < minRewardValue) {
            return IOracle(position.collateralOracle).getAmount(minRewardValue);
        } else if (baseRewardValue > maxRewardValue) {
            return IOracle(position.collateralOracle).getAmount(maxRewardValue);
        } else {
            return IOracle(position.collateralOracle).getAmount(baseRewardValue);
        }
    }

    /// @notice returns true if reward for parameters 0 always greater than or equal to parameters 1
    function isGTE(bytes calldata parameters0, bytes calldata parameters1) external view returns (bool) {
        (uint256 vr0, uint256 min0, uint256 max0) = decodeParameters(parameters0);
        (uint256 vr1, uint256 min1, uint256 max1) = decodeParameters(parameters1);
        return (vr0 >= vr1 && min0 >= min1 && max0 >= max1) ? true : false;
    }

    function isLTE(bytes calldata parameters0, bytes calldata parameters1) external view returns (bool) {
        (uint256 vr0, uint256 min0, uint256 max0) = decodeParameters(parameters0);
        (uint256 vr1, uint256 min1, uint256 max1) = decodeParameters(parameters1);
        return (vr0 < vr1 && min0 < min1 && max0 < max1) ? true : false;
    }
}
