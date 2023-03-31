// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {IAssessor} from "src/modules/assessor/IAssessor.sol";
import {IPosition} from "src/terminal/IPosition.sol";
import {Agreement} from "src/libraries/LibOrderBook.sol";

/*
 * Example Assessor type that calculates cost using configurable origination fee, interest rate, and profit share ratio.
 */

struct Parameters {
    uint256 originationFeeRatio;
    uint256 interestRatio;
    uint256 profitShareRatio;
}

contract StandardAssessor is IAssessor {
    uint256 private constant RATIO_DECIMALS = 1e18;

    /// @notice Return the cost of a loan, quantified in the Loan Asset.
    function getCost(Agreement calldata agreement) external view override returns (uint256) {
        Parameters memory p = abi.decode(agreement.assessor.parameters, (Parameters));
        uint256 positionValue = IPosition(agreement.positionAddr).getAmount(agreement.terminal.parameters); // duplicate decode here
        uint256 originationFee = (agreement.loanAmount * p.originationFeeRatio) / RATIO_DECIMALS;
        uint256 interest = ((block.timestamp - agreement.deploymentTime) * p.interestRatio) / RATIO_DECIMALS;
        uint256 profit = positionValue - originationFee - interest - agreement.loanAmount;
        uint256 profitShare = profit > 0 ? (profit * p.profitShareRatio) / RATIO_DECIMALS : 0;
        return originationFee + interest + profitShare;
    }

    function isGTE(bytes calldata parameters0, bytes calldata parameters1) external pure returns (bool) {
        Parameters memory p0 = abi.decode(parameters0, (Parameters));
        Parameters memory p1 = abi.decode(parameters1, (Parameters));
        return (
            p0.originationFeeRatio >= p1.originationFeeRatio && p0.interestRatio >= p1.interestRatio
                && p0.profitShareRatio >= p1.profitShareRatio
        );
    }

    function isLTE(bytes calldata parameters0, bytes calldata parameters1) external pure returns (bool) {
        Parameters memory p0 = abi.decode(parameters0, (Parameters));
        Parameters memory p1 = abi.decode(parameters1, (Parameters));
        return (
            p0.originationFeeRatio <= p1.originationFeeRatio && p0.interestRatio <= p1.interestRatio
                && p0.profitShareRatio <= p1.profitShareRatio
        );
    }
}
