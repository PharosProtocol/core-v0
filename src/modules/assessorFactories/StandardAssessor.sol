// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {AssessorFactory} from "src/modules/AssessorFactory.sol";
import {IPosition} from "src/modules/PositionFactory.sol";

/*s
 * Example Assessor type that calculates cost using configurable origination fee, interest rate, and profit share ratio.
 */
contract StandardAssessor is AssessorFactory {
    uint256 private constant RATIO_DECIMALS = 1e18;

    uint256 private originationFeeRatio;
    uint256 private interestRatio;
    uint256 private profitShareRatio;

    // Initialization logic used by all clones of ~this~ Assessor.
    function setArguments() internal override initializer {
        (originationFeeRatio, interestRatio, profitShareRatio) =
            abi.decode(creationArguments, (uint256, uint256, uint256));
    }

    function getCost(address position) external view override returns (uint256) {
        IPosition positionInterface = IPosition(position);
        uint256 positionValue = positionInterface.getValue();
        (, uint256 initAmount, uint256 initTime) = positionInterface.getInitState();
        uint256 originationFee = initAmount * originationFeeRatio / RATIO_DECIMALS;
        uint256 interest = (block.timestamp - initTime) * interestRatio / RATIO_DECIMALS;
        uint256 profit = positionValue - originationFee - interest - initAmount;
        uint256 profitShare = profit > 0 ? profit * profitShareRatio / RATIO_DECIMALS : 0;
        return originationFee + interest + profitShare;
    }

    function isGTE(bytes calldata altArguments) external view override returns (bool) {
        (uint256 ofr, uint256 ir, uint256 psr) = abi.decode(altArguments, (uint256, uint256, uint256));
        return (originationFeeRatio >= ofr && interestRatio >= ir && profitShareRatio >= psr) ? true : false;
    }

    function isLTE(bytes calldata altArguments) external view override returns (bool) {
        (uint256 ofr, uint256 ir, uint256 psr) = abi.decode(altArguments, (uint256, uint256, uint256));
        return (originationFeeRatio <= ofr && interestRatio <= ir && profitShareRatio <= psr) ? true : false;
    }
}
