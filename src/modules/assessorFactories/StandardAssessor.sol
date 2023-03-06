// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {IAssessor} from "src/modules/AssessorFactory.sol";
import {IPosition} from "src/modules/PositionFactory.sol";
import {ComparableParameterFactory} from "src/modules/Factory.sol";

/*
 * Example Assessor type that calculates cost using configurable origination fee, interest rate, and profit share ratio.
 */
interface IStandardAssessor is IAssessor {
    function getParameters() external view returns (uint256, uint256, uint256);
}

contract StandardAssessor is IStandardAssessor, ComparableParameterFactory {
    uint256 private constant RATIO_DECIMALS = 1e18;

    uint256 private originationFeeRatio;
    uint256 private interestRatio;
    uint256 private profitShareRatio;

    // Initialization logic used by all clones of ~this~ Assessor.
    function initialize(bytes calldata parameters) external override initializer {
        (originationFeeRatio, interestRatio, profitShareRatio) = abi.decode(parameters, (uint256, uint256, uint256));
    }

    function getParameters() external view returns (uint256, uint256, uint256) {
        return (originationFeeRatio, interestRatio, profitShareRatio);
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

    function _isGT(address clone0, address clone1) internal view override returns (bool) {
        (uint256 ofr0, uint256 ir0, uint256 psr0) = IStandardAssessor(clone0).getParameters();
        (uint256 ofr1, uint256 ir1, uint256 psr1) = IStandardAssessor(clone1).getParameters();
        return (ofr0 > ofr1 && ir0 > ir1 && psr0 > psr1) ? true : false;
    }

    function _isLT(address clone0, address clone1) internal view override returns (bool) {
        (uint256 ofr0, uint256 ir0, uint256 psr0) = IStandardAssessor(clone0).getParameters();
        (uint256 ofr1, uint256 ir1, uint256 psr1) = IStandardAssessor(clone1).getParameters();
        return (ofr0 < ofr1 && ir0 < ir1 && psr0 < psr1) ? true : false;
    }
}
