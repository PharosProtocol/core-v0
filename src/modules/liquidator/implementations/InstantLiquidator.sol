// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {C} from "src/C.sol";
import {Liquidator} from "src/modules/liquidator/ILiquidator.sol";
import "src/LibUtil.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {IPosition} from "src/Terminal/IPosition.sol";
import {IAssessor} from "src/modules/assessor/IAssessor.sol";
import {IAccount} from "src/modules/account/IAccount.sol";
import {IOracle} from "src/modules/oracle/IOracle.sol";

struct Parameters {
    uint256 valueRatio;
    uint256 minRewardValue;
    uint256 maxRewardValue;
}

/*
 * Liquidate a position by giving all assets to liquidator and verifying that end balances for lender and borrower are
 * as expected. Priority: liquidator, lender, borrower. Only useable with ERC20s due to need for divisibility.
 * Liquidator reward is a ratio of position value with absolute minimum and maximum value.
 */

contract InstantLiquidator is Liquidator {
    event Liquidated(address position, uint256 lenderReturn, uint256 borrowerReturn);

    function verifyCompatibility(Agreement memory agreement) external pure {
        require(agreement.loanAsset.standard == ERC20_STANDARD, "loan asset must be ERC20"); // can also do eth?
        require(agreement.collateralAsset.standard == ERC20_STANDARD, "collateral asset must be ERC20"); // can also do eth?
    }

    function _liquidate(Agreement memory agreement) internal override {
        // Parameters memory params = abi.decode(parameters, (Parameters));

        // require(liquidating[agreement.positionAddr], "position not in liquidation phase");

        uint256 lenderReturnExpected;
        uint256 borrowerReturnExpected;
        {
            IPosition position = IPosition(agreement.positionAddr);
            uint256 positionAmount = position.getExitAmount(agreement.position.parameters); // denoted in loan asset

            // Distribution of value. Priority: liquidator, lender, borrower.
            uint256 liquidatorReward = getRewardValue(agreement); // denoted in loan asset
            uint256 lenderCap = agreement.loanAmount + IAssessor(agreement.assessor.addr).getCost(agreement); // denoted in loan asset

            if (positionAmount < liquidatorReward) {
                lenderReturnExpected = 0;
                borrowerReturnExpected = 0;
            } else if (positionAmount < liquidatorReward + lenderCap) {
                lenderReturnExpected = positionAmount - liquidatorReward;
                borrowerReturnExpected = 0;
            } else {
                lenderReturnExpected = lenderCap;
                borrowerReturnExpected = positionAmount - lenderReturnExpected - liquidatorReward; // might be profitable for borrower or not
            }
        }

        IAccount lenderAccount = IAccount(agreement.lenderAccount.addr);
        IAccount borrowerAccount = IAccount(agreement.borrowerAccount.addr);

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
            Utils.receiveAsset(msg.sender, agreement.loanAsset, lenderReturnExpected);
            lenderAccount.load{value: Utils.isEth(agreement.loanAsset) ? lenderReturnExpected : 0}(
                agreement.loanAsset, lenderReturnExpected, agreement.lenderAccount.parameters
            );
        }
        if (borrowerReturnExpected > 0) {
            Utils.receiveAsset(msg.sender, agreement.collateralAsset, borrowerReturnExpected);
            borrowerAccount.load{value: Utils.isEth(agreement.collateralAsset) ? borrowerReturnExpected : 0}(
                agreement.collateralAsset, borrowerReturnExpected, agreement.borrowerAccount.parameters
            );
        }
        IPosition(agreement.positionAddr).transferContract(msg.sender);

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
    function getRewardValue(Agreement memory agreement) public view returns (uint256) {
        Parameters memory p = abi.decode(agreement.liquidator.parameters, (Parameters));

        uint256 loanValue = IOracle(agreement.loanOracle.addr).getValue(
            agreement.loanAsset, agreement.loanAmount, agreement.loanOracle.parameters
        );
        uint256 baseRewardValue = loanValue * p.valueRatio / C.RATIO_FACTOR;
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
