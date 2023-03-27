// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {ILiquidator} from "src/modules/liquidators/ILiquidator.sol";
import "src/libraries/LibUtil.sol";

struct Parameters {
    uint256 valueRatio;
    uint256 minRewardValue;
    uint256 maxRewardValue;
}

// interface ILiquidator {
//     function returnAssets(Agreement agreement, uint256 lenderOwed, uint256 borrowerOwed) external;
// }

/*
 * Liquidate a position by giving all assets to liquidator and verifying that end balances for lender and borrower are
 * as expected. Priority: liquidator, lender, borrower. Only useable with ERC20s due to need for divisibility.
 * Liquidator reward is a ratio of position value with absolute minimum and maximum value.
 */

contract InstantReward is Liquidator {
    address private constant UNI_V2_ROUTER02 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    uint256 private constant RATIO_FACTOR = 1e18;
    uint256 private constant MAX_SLIPPAGE = 10; // 10% slippage

    event Liquidated(address position, uint256 lenderReturn, uint256 borrowerReturn);

    function verifyCompatibility(Agreement agreement, bytes parameters) external view {
        require(agreement.loanAsset.standard == ERC20_STANDARD, "loan asset must be ERC20"); // can also do eth?
        require(agreement.collateralAsset.standard == ERC20_STANDARD, "collateral asset must be ERC20"); // can also do eth?
    }

    function _liquidate(Agreement memory agreement) external override {
        Parameters memory params = abi.decode(parameters, (Parameters));

        require(liquidating[agreement.positionAddr], "position not in liquidation phase");

        IPosition position = IPosition(agreement.positionAddr);
        uint256 positionValue = position.getValue(); // denoted in loan asset

        // Distribution of value. Priority: liquidator, lender, borrower.
        uint256 liquidatorReward = getRewardValue(agreement); // denoted in loan asset
        uint256 lenderCap = agreement.loanAmount + IAssessor(agreement.assessor.addr).getCost(agreement); // denoted in loan asset

        uint256 lenderReturnExpected;
        uint256 borrowerReturnExpected;

        if (positionValue < liquidatorReward) {
            lenderReturnExpected = 0;
            borrowerReturnExpected = 0;
        } else if (positionValue < liquidatorReward + lenderCap) {
            lenderReturnExpected = positionValue - liquidatorReward;
            borrowerReturnExpected = 0;
        } else {
            lenderReturnExpected = lenderCap;
            borrowerReturnExpected = positionValue - lenderReturnExpected - liquidatorReward; // might be profitable for borrower or not
        }

        IAccount lenderAccount = Account(agreement.lender);
        IAccount borrowerAccount = Account(agreement.borrower);

        /**
         * OPTION 1 - Liquidator takes position and handles callback **
         */
        // lenderBalanceBefore = lenderAccount.getAssetBalance(agreement.loanAsset);
        // borrowerBalanceBefore = borrowerAccount.getAssetBalance(agreement.collateralAsset); // this should be balance wi/o collateral, regardless of whether collateral literally leaves the account or not
        // // Callback to allow liquidator to do whatever it wants with the position as long as it returns the expected Returns.
        // IPosition(agreement.positionAddr).setOwner(msg.sender);
        // ILiquidator(msg.sender).returnAssets(agreement, lenderReturnExpected, borrowerReturnExpected);
        // require(
        //     lenderAccount.getAssetBalance(agreement.loanAsset) >= lenderBalanceBefore + lenderReturnExpected,
        //     "lender balance too low"
        // );
        // require(
        //     borrowerAccount.getAssetBalance(agreement.collateralAsset) >= borrowerBalanceBefore + borrowerReturnExpected,
        //     "borrower balance too low"
        // );

        /**
         * OPTION 2 - Liquidator prepays assets less reward and keeps position for later handling (no callback) **
         */
        // NOTE Inefficient asset passthrough here, but can be optimized later if we go this route.
        if (lenderReturnExpected > 0) {
            uint256 value;
            if (agreement.loanAsset.standard == ETH_STANDARD) {
                value = lenderReturnExpected;
            } else if (agreement.loanAsset.standard == ERC20_STANDARD) {
                IERC20 loanAsset = IERC20(agreement.loanAsset.addr); // NOTE double spend concerns?
                loanAsset.approve(agreement.lendAccount.addr, lenderReturnExpected);
            }
            lenderAccount.addAssets{value: value}(
                [agreement.loanAsset], [lenderReturnExpected], agreement.lendAccount.parameters
            );
        }
        if (borrowerReturnExpected > 0) {
            uint256 value;
            if (agreement.collateralAsset.standard == ETH_STANDARD) {
                value = borrowerReturnExpected;
            } else if (agreement.collateralAsset.standard == ERC20_STANDARD) {
                IERC20 collateralAsset = IERC20(agreement.collateralAsset.addr); // NOTE double spend concerns?
                collateralAsset.approve(agreement.borrowAccount.addr, borrowerReturnExpected);
            }
            borrowAccount.addAssets(
                [agreement.collateralAsset], [borrowerReturnExpected], agreement.borrowAccount.parameters
            );
        }
        IPosition(agreement.positionAddr).setOwner(msg.sender);

        emit Liquidated(agreement.positionAddr, lenderReturnExpected, borrowerReturnExpected);
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

    /// @dev may return a number that is larger than the total collateral amount
    function getRewardValue(Agreement calldata agreement) private view returns (uint256) {
        Parameters memory p = abi.decode(agreement.liquidator.parameters, (Parameters));

        uint256 loanValue = IOracle(agreement.loanOracle.addr).getValue(
            agreement.loanAsset, agreement.loanAmount, agreement.loanOracle.parameters
        );
        uint256 baseRewardValue = loanValue * p.valueRatio / RATIO_FACTOR;
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
}
