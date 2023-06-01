// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {C} from "src/C.sol";
import {Liquidator} from "../Liquidator.sol";
import "src/LibUtil.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {IAccount} from "src/interfaces/IAccount.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

/*
 * Liquidate a position at kick time by giving closing the position and having position contract distribute loan and 
 * collateral assets between liquidator, lender, and borrower. Only useable with ERC20s due to need for divisibility.
 * Liquidator reward is a ratio of collateral amount, and maximum is 100% of collateral assets.
 */

contract InstantPositionPay is Liquidator {
    struct Parameters {
        uint256 rewardCollAmountRatio;
    }

    constructor(address bookkeeperAddr) Liquidator(bookkeeperAddr) {}

    /// @notice Do nothing.
    function _receiveKick(Agreement calldata agreement) internal override {
        _liquidate(agreement);
    }

    /// @notice Liquidator prepays assets less reward and keeps position for later handling (no callback).
    function _liquidate(Agreement calldata agreement) private {
        Parameters memory params = abi.decode(agreement.liquidator.parameters, (Parameters));

        // require(liquidating[agreement.position.addr], "position not in liquidation phase");

        IPosition position = IPosition(agreement.position.addr);
        uint256 positionAmount = position.close(msg.sender, agreement, false, agreement.position.parameters); // denoted in loan asset

        // Split loan asset in position between lender and borrower. Lender gets priority.
        uint256 lenderAmount =
            agreement.loanAmount + IAssessor(agreement.assessor.addr).getCost(agreement, positionAmount);
        if (lenderAmount > 0) {
            (bool success,) = IPosition(agreement.position.addr).passThrough(
                payable(agreement.lenderAccount.addr),
                abi.encodeWithSelector(
                    IAccount.load.selector, agreement.loanAsset, lenderAmount, agreement.lenderAccount.parameters
                ),
                false
            );
            require(success, "Failed to send loan asset to lender account");
        }

        // Might be profitable for borrower or not.
        if (positionAmount > lenderAmount) {
            (bool success,) = IPosition(agreement.position.addr).passThrough(
                payable(agreement.borrowerAccount.addr),
                abi.encodeWithSelector(
                    IAccount.load.selector,
                    agreement.loanAsset,
                    positionAmount - lenderAmount,
                    agreement.borrowerAccount.parameters
                ),
                false
            );
            require(success, "Failed to send loan asset to borrower account");
        }

        // Split collateral between liquidator and borrower. Liquidator gets priority.
        uint256 rewardCollAmount = agreement.collAmount * params.rewardCollAmountRatio / C.RATIO_FACTOR;
        if (rewardCollAmount < agreement.collAmount) {
            (bool success,) = IPosition(agreement.position.addr).passThrough(
                payable(agreement.borrowerAccount.addr),
                abi.encodeWithSelector(
                    IAccount.load.selector,
                    agreement.collAsset,
                    agreement.collAmount - rewardCollAmount,
                    agreement.borrowerAccount.parameters
                ),
                false
            );
            require(success, "Failed to send collateral asset to borrower account");
        }
        // All remaining collateral asset goes to liquidator.
        if (rewardCollAmount > 0) {
            // d4e3bdb6: safeErc20Transfer(address,address,uint256)
            (bool success,) = IPosition(agreement.position.addr).passThrough(
                payable(address(Utils)),
                abi.encodeWithSelector(
                    Utils.safeErc20Transfer.selector, agreement.collAsset.addr, msg.sender, rewardCollAmount
                ),
                true
            );
            require(success, "Failed to send collateral asset to liquidator");
        }

        position.transferContract(msg.sender);

        emit Liquidated(agreement.position.addr, msg.sender);
    }

    function canHandleAssets(Asset calldata loanAsset, Asset calldata collAsset, bytes calldata)
        external
        pure
        override
        returns (bool)
    {
        if (loanAsset.standard == ERC20_STANDARD && collAsset.standard != ERC20_STANDARD) return true;
        return false;
    }
}
