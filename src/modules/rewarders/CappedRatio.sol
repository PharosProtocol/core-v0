// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {IOracle} from "src/interfaces/IOracle.sol";
import {IRewarder} from "src/interfaces/IRewarder.sol";
import {PositionTerms} from "src/libraries/LibOrderBook.sol";
import {OracleParameters} from "src/libraries/LibOracle.sol";

/*
 * Example Rewarder type that calculates reward as a ratio of *loan value*, with a minimum and maximum reward.
 */
interface ICappedRatio is IRewarder {
    function decodeParameters(bytes calldata parameters)
        external
        view
        returns (uint256 valueRatio, uint256 minRewardValue, uint256 maxRewardValue);
}

contract CappedRatio is ICappedRatio {
    uint256 private constant RATIO_BASE = 1e6; // NOTE what is a good scale to use for ratios? enough precision and less overflow

    function decodeParameters(bytes calldata parameters) public pure returns (uint256, uint256, uint256) {
        return abi.decode(parameters, (uint256, uint256, uint256));
    }

    /// @dev may return a number that is larger than the total collateral amount
    function getRewardValue(PositionTerms calldata positionTerms) external view returns (uint256) {
        (uint256 valueRatio, uint256 minRewardValue, uint256 maxRewardValue) =
            decodeParameters(positionTerms.rewarder.parameters);

        uint256 loanValue = IOracle(positionTerms.loanOracle.addr).getValue(
            positionTerms.loanAmount, abi.decode(positionTerms.loanOracle.parameters, (OracleParameters))
        );
        uint256 baseRewardValue = loanValue * valueRatio / RATIO_BASE;
        // NOTE what if total collateral value < minRewardValue?
        if (baseRewardValue < minRewardValue) {
            return IOracle(positionTerms.collateralOracle.addr).getAmount(
                minRewardValue, abi.decode(positionTerms.loanOracle.parameters, (OracleParameters))
            );
        } else if (baseRewardValue > maxRewardValue) {
            return IOracle(positionTerms.collateralOracle.addr).getAmount(
                maxRewardValue, abi.decode(positionTerms.loanOracle.parameters, (OracleParameters))
            );
        } else {
            return IOracle(positionTerms.collateralOracle.addr).getAmount(
                baseRewardValue, abi.decode(positionTerms.loanOracle.parameters, (OracleParameters))
            );
        }
    }

    /// @notice returns true if reward for parameters 0 always greater than or equal to parameters 1
    function isGTE(bytes calldata parameters0, bytes calldata parameters1) external pure returns (bool) {
        (uint256 vr0, uint256 min0, uint256 max0) = decodeParameters(parameters0);
        (uint256 vr1, uint256 min1, uint256 max1) = decodeParameters(parameters1);
        return (vr0 >= vr1 && min0 >= min1 && max0 >= max1) ? true : false;
    }

    function isLTE(bytes calldata parameters0, bytes calldata parameters1) external pure returns (bool) {
        (uint256 vr0, uint256 min0, uint256 max0) = decodeParameters(parameters0);
        (uint256 vr1, uint256 min1, uint256 max1) = decodeParameters(parameters1);
        return (vr0 < vr1 && min0 < min1 && max0 < max1) ? true : false;
    }
}
