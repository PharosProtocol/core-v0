// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {Liquidator} from "../Liquidator.sol";
import "src/libraries/LibUtil.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {IAccount} from "src/interfaces/IAccount.sol";
import {IOracle} from "src/interfaces/IOracle.sol";

/*
 * Liquidate a position at kick time and distribute loan and 
 * collateral assets between liquidator, lender, and borrower. Only useable with ERC20s due to need for divisibility.
 */

abstract contract InstantErc20 is Liquidator {
    constructor(address bookkeeperAddr) Liquidator(bookkeeperAddr) {}

    /// @notice Liquidator prepays assets less reward and keeps position for later handling (no callback).
    function _liquidate(address sender, Agreement calldata agreement, bool closePosition) internal {
        // require(liquidating[agreement.position.addr], "position not in liquidation phase");

        IPosition position = IPosition(agreement.position.addr);

        uint256 positionAmount;
        if (closePosition) {
            positionAmount = position.close(sender, agreement, false, agreement.position.parameters);
        } else {
            // NOTE security - what happens to erc20 transfer if amount is 0?
            positionAmount = position.getCloseAmount(agreement.position.parameters);
            (bool success,) = IPosition(agreement.position.addr).passThrough(
                payable(address(Utils)),
                abi.encodeWithSelector(
                    Utils.safeErc20TransferFrom.selector,
                    agreement.loanAsset.addr,
                    sender,
                    agreement.position.addr,
                    positionAmount
                ),
                true
            );
            require(success, "Failed to send loan asset to position");
        }

        // Split loan asset in position between lender and borrower. Lender gets priority.
        uint256 lenderAmount =
            agreement.loanAmount + IAssessor(agreement.assessor.addr).getCost(agreement, positionAmount);
        if (lenderAmount > 0) {
            loadFromPosition(position, agreement.lenderAccount, agreement.loanAsset, lenderAmount);
        }

        // Might be profitable for borrower or not.
        if (positionAmount > lenderAmount) {
            loadFromPosition(position, agreement.borrowerAccount, agreement.loanAsset, positionAmount - lenderAmount);
        }

        // Collateral asset is split between liquidator and borrower. Priority to liquidator.
        uint256 rewardCollAmount = getRewardCollAmount(agreement);
        if (agreement.collAmount < rewardCollAmount) rewardCollAmount = agreement.collAmount;

        // Spare collateral goes back to borrower.
        if (agreement.collAmount > rewardCollAmount) {
            loadFromPosition(
                position, agreement.borrowerAccount, agreement.collAsset, agreement.collAmount - rewardCollAmount
            );
        }

        // Reward goes direct to liquidator.
        if (rewardCollAmount > 0) {
            // d4e3bdb6: safeErc20Transfer(address,address,uint256)
            (bool success,) = IPosition(agreement.position.addr).passThrough(
                payable(address(Utils)),
                abi.encodeWithSelector(
                    Utils.safeErc20Transfer.selector, agreement.collAsset.addr, sender, rewardCollAmount
                ),
                true
            );
            require(success, "Failed to send collateral asset to liquidator");
        }

        position.transferContract(sender);

        emit Liquidated(agreement.position.addr, sender);
    }

    // NOTE could this be improved by doing sideLoad in bookkeeper (w/o knowledge of asset handling) and then having
    //      bookkeeper report Asset(s) and Loaded amount(s) at kick time?  Trusted bookkeeper sideload reduces # of
    //      asset transfers by 1 per asset.
    /// @notice Load assets from position to an account.
    function loadFromPosition(IPosition position, ModuleReference memory account, Asset memory asset, uint256 amount)
        private
    {
        (bool success,) = position.passThrough(
            payable(asset.addr), abi.encodeWithSelector(IERC20.approve.selector, account.addr, amount), false
        );
        require(success, "Failed to approve position ERC20 spend");
        // SECURITY why does anyone involved in the agreement care if liquidator uses loadFromPosition vs
        //          loadFromUser? It is basically passing up on ownership of account assets. A hostile liquidator
        //          implementation could then essentially siphon off assets in an account without loss by lender
        //          or borrower.
        (success,) = position.passThrough(
            payable(account.addr),
            abi.encodeWithSelector(IAccount.loadFromUser.selector, asset, amount, account.parameters),
            false
        );
        require(success, "Failed to load asset from position to account");
    }

    /// @notice Returns amount of collateral asset that is due to the liquidator.
    /// @dev may return a number that is larger than the total collateral amount.
    function getRewardCollAmount(Agreement memory agreement) public view virtual returns (uint256 rewardCollAmount);

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
