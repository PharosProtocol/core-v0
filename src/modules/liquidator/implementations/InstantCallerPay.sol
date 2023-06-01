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
 * Liquidate a position at kick time by pulling assets from caller and distributing to lender and borrower. Liquidator
 * then gets to keep position with collateral assets and position intact. This liquidator is expected to be useful
 * when a liquidator values a position or collateral above the market value, and is willing to pay a gas premium for it.
 */

contract InstantLiquidator is Liquidator {
    struct Parameters {
        uint256 valueRatio;
    }

    constructor(address bookkeeperAddr) Liquidator(bookkeeperAddr) {}

    /// @notice Do nothing.
    function _receiveKick(address kicker, Agreement calldata agreement) internal override {}

    /// @notice Liquidator prepays assets less reward and keeps position for later handling (no callback).
    function liquidate(Agreement calldata agreement) external {
        // Parameters memory params = abi.decode(parameters, (Parameters));

        // require(liquidating[agreement.position.addr], "position not in liquidation phase");

        uint256 lenderReturnExpected;
        uint256 borrowerReturnExpected;
        {
            IPosition position = IPosition(agreement.position.addr);
            uint256 positionAmount = position.getCloseAmount(agreement.position.parameters); // denoted in loan asset

            // NOTE Inefficient asset passthrough here, but can be optimized later if we go this route.
            Utils.safeErc20TransferFrom(agreement.loanAsset.addr, msg.sender, address(this), positionAmount);

            // Split loan asset in position between lender and borrower. Lender gets priority.
            uint256 lenderAmount =
                agreement.loanAmount + IAssessor(agreement.assessor.addr).getCost(agreement, positionAmount);
            IAccount(agreement.lenderAccount.addr).load(
                agreement.loanAsset, lenderAmount, agreement.lenderAccount.parameters
            );
            // Might be profitable for borrower or not.
            if (positionAmount > lenderAmount) {
                IAccount(agreement.lenderAccount.addr).load(
                    agreement.loanAsset, positionAmount - lenderAmount, agreement.borrowerAccount.parameters
                );
            }
            // IAccount(agreement.lenderAccount.addr).loadFrom(...sender?
            //     agreement.loanAsset, lenderAmount, agreement.lenderAccount.parameters
            // );
            // IAccount(agreement.lenderAccount.addr).loadFrom(...sender?
            //     agreement.loanAsset, borrowerAmount, agreement.borrowerAccount.parameters
            // );

            // NOTE collateral could be sent loaded directly from position contract by using passthrough function. While
            //      liquidator is admin. Save a bit of gas.
            // Split collateral between liquidator and borrower. Liquidator gets priority.
            uint256 rewardCollAmount = getRewardCollAmount(agreement);
            if (rewardCollAmount < agreement.collAmount) {
                uint256 borrowerCollAmount = agreement.collAmount - rewardCollAmount;
                Utils.safeErc20TransferFrom(agreement.collAsset.addr, msg.sender, address(this), borrowerCollAmount);
                IAccount(agreement.borrowerAccount.addr).load(
                    agreement.collAsset, borrowerCollAmount, agreement.borrowerAccount.parameters
                );
                // IAccount(agreement.lenderAccount.addr).loadFrom(...sender?
                //     agreement.collAsset, borrowerCollAmount, agreement.borrowerAccount.parameters
                // );
            }
            // All remaining collateral asset goes to liquidator.
        }

        IPosition(agreement.position.addr).transferContract(msg.sender);

        emit Liquidated(agreement.position.addr, msg.sender);
    }

    /// @notice Returns amount of collateral asset that is due to the liquidator.
    /// @dev may return a number that is larger than the total collateral amount
    function getRewardCollAmount(Agreement calldata agreement) public view returns (uint256) {
        Parameters memory p = abi.decode(agreement.liquidator.parameters, (Parameters));

        uint256 loanValue = IOracle(agreement.loanOracle.addr).getValue(
            agreement.loanAsset, agreement.loanAmount, agreement.loanOracle.parameters
        );
        uint256 rewardValue = loanValue * p.valueRatio / C.RATIO_FACTOR;
        return IOracle(agreement.collateralOracle.addr).getAmount(
            agreement.loanAsset, rewardValue, agreement.collateralOracle.parameters
        );
    }

    function canHandleAssets(Asset calldata loanAsset, Asset calldata collAsset, bytes calldata)
        external
        pure
        override
        returns (bool)
    {
        if (loanAsset.standard == ERC20_STANDARD && collAsset.standard == ERC20_STANDARD) return true;
        return false;
    }
}
