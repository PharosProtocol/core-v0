// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "forge-std/console.sol";

import {Assessor} from "../Assessor.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {Asset} from "src/LibUtil.sol";
import {C} from "src/C.sol";

/*
 * Example Assessor type that calculates cost using configurable origination fee, interest rate, and profit share ratio.
 * Cost is in loan asset.
 */

contract StandardAssessor is Assessor {
    struct Parameters {
        uint256 originationFeeRatio;
        uint256 interestRatio;
        uint256 profitShareRatio;
    }

    /// @notice Return the cost of a loan, quantified in the Loan Asset.
    function getCost(Agreement calldata agreement) external view override returns (uint256 amount) {
        Parameters memory p = abi.decode(agreement.assessor.parameters, (Parameters));
        uint256 positionValue = IPosition(agreement.position.addr).getExitAmount(agreement.position.parameters); // duplicate decode here
        uint256 originationFee = agreement.loanAmount * p.originationFeeRatio / C.RATIO_FACTOR;
        uint256 interest =
            agreement.loanAmount * (block.timestamp - agreement.deploymentTime) * p.interestRatio / C.RATIO_FACTOR;
        uint256 lenderValue = originationFee + interest + agreement.loanAmount;
        uint256 profitShare =
            positionValue > lenderValue ? (positionValue - lenderValue) * p.profitShareRatio / C.RATIO_FACTOR : 0;

        amount = originationFee + interest + profitShare;
        console.log("cost: %s", amount);
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
