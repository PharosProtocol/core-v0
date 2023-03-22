// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {IAssessor} from "src/interfaces/IAssessor.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {Agreement} from "src/libraries/LibOrderBook.sol";

/*
 * Example Assessor type that calculates cost using configurable origination fee, interest rate, and profit share ratio.
 */
interface IStandardAssessor is IAssessor {
    function decodeParameters(bytes calldata parameters)
        external
        view
        returns (uint256 originationFeeRatio, uint256 interestRatio, uint256 profitShareRatio);
}

contract StandardAssessor is IStandardAssessor {
    uint256 private constant RATIO_DECIMALS = 1e18;

    function decodeParameters(bytes calldata parameters) public pure returns (uint256, uint256, uint256) {
        return abi.decode(parameters, (uint256, uint256, uint256));
    }

    /// @notice Return the cost of a loan, quantified in the Loan Asset.
    function getCost(Agreement calldata agreement) external view override returns (uint256) {
        (uint256 originationFeeRatio, uint256 interestRatio, uint256 profitShareRatio) =
            decodeParameters(agreement.assessor.parameters);
        uint256 positionValue = IPosition(agreement.addr).getValue(agreement.terminal.parameters); // duplicate decode here
        uint256 originationFee = (agreement.loanAmount * originationFeeRatio) / RATIO_DECIMALS;
        uint256 interest = ((block.timestamp - agreement.deploymentTime) * interestRatio) / RATIO_DECIMALS;
        uint256 profit = positionValue - originationFee - interest - agreement.loanAmount;
        uint256 profitShare = profit > 0 ? (profit * profitShareRatio) / RATIO_DECIMALS : 0;
        return originationFee + interest + profitShare;
    }

    function isGTE(bytes calldata parameters0, bytes calldata parameters1) external pure returns (bool) {
        (uint256 ofr0, uint256 ir0, uint256 psr0) = decodeParameters(parameters0);
        (uint256 ofr1, uint256 ir1, uint256 psr1) = decodeParameters(parameters1);
        return (ofr0 >= ofr1 && ir0 >= ir1 && psr0 >= psr1) ? true : false;
    }

    function isLTE(bytes calldata parameters0, bytes calldata parameters1) external pure returns (bool) {
        (uint256 ofr0, uint256 ir0, uint256 psr0) = decodeParameters(parameters0);
        (uint256 ofr1, uint256 ir1, uint256 psr1) = decodeParameters(parameters1);
        return (ofr0 <= ofr1 && ir0 <= ir1 && psr0 <= psr1) ? true : false;
    }
}
