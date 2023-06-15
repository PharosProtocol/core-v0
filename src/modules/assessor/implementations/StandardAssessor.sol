// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Assessor} from "../Assessor.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import "src/libraries/LibUtil.sol";
import {C} from "src/libraries/C.sol";

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
    function getCost(Agreement calldata agreement, uint256 currentAmount) external view override returns (uint256) {
        Parameters memory params = abi.decode(agreement.assessor.parameters, (Parameters));
        uint256 originationFee = agreement.loanAmount * params.originationFeeRatio / C.RATIO_FACTOR;
        uint256 interest =
            agreement.loanAmount * (block.timestamp - agreement.deploymentTime) * params.interestRatio / C.RATIO_FACTOR;
        uint256 lenderAmount = originationFee + interest + agreement.loanAmount;
        uint256 profitShare =
            currentAmount > lenderAmount ? (currentAmount - lenderAmount) * params.profitShareRatio / C.RATIO_FACTOR : 0;

        return originationFee + interest + profitShare;
    }

    // Although the assessor is not moving assets around, this assessment only makes sense with divisible assets.
    // Collateral asset is irrelevant.
    function canHandleAsset(Asset calldata asset, bytes calldata) external pure override returns (bool) {
        if (asset.standard == ERC20_STANDARD) return true;
        return false;
    }
}
