// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Assessor} from "../Assessor.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {C} from "src/libraries/C.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset, ERC20_STANDARD} from "src/libraries/LibUtils.sol";

/*
 * Example Assessor type that calculates cost using configurable origination fee, interest rate, and profit share ratio.
 * Cost denomination asset is configurable, but must be ETH or ERC20 asset.
 * Cost asset must be the same as the loan asset.
 */

contract StandardAssessor is Assessor {
    struct Parameters {
        Asset asset;
        uint256 originationFeeRatio;
        uint256 interestRatio;
        uint256 profitShareRatio;
    }

    /// @notice Return the cost of a loan, quantified in the Loan Asset. This simplifies compatibility matrix.
    // NOTE this will not be compatible if borrowing a non-divisible asset.
    function _getCost(
        Agreement calldata agreement,
        uint256 currentAmount
    ) internal view override returns (Asset memory asset, uint256 amount) {
        Parameters memory params = abi.decode(agreement.assessor.parameters, (Parameters));
        uint256 originationFee = (agreement.loanAmount * params.originationFeeRatio) / C.RATIO_FACTOR;
        uint256 interest = (agreement.loanAmount *
            (block.timestamp - agreement.deploymentTime) *
            params.interestRatio) / C.RATIO_FACTOR;
        uint256 lenderAmount = originationFee + interest + agreement.loanAmount;
        uint256 profitShare = currentAmount > lenderAmount
            ? ((currentAmount - lenderAmount) * params.profitShareRatio) / C.RATIO_FACTOR
            : 0;

        return (params.asset, originationFee + interest + profitShare);
    }

    // Although the assessor is not moving assets around, this assessment only makes sense with divisible assets.
    // Collateral asset is irrelevant.
    // Requires cost asset == loan asset.
    function canHandleAsset(Asset calldata asset, bytes calldata parameters) external pure override returns (bool) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        if (asset.standard != ERC20_STANDARD) return false;
        if (keccak256(abi.encode(asset)) != keccak256(abi.encode(params.asset))) return false;
        return true;
    }
}
