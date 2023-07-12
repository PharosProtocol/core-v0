// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {C} from "src/libraries/C.sol";
import {Asset, ETH_STANDARD, ERC20_STANDARD, LibUtils} from "src/libraries/LibUtils.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";
import {Liquidator} from "../Liquidator.sol";
import {Agreement, ModuleReference} from "src/libraries/LibBookkeeper.sol";
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

        /**
         * Collateral Asset *
         */

        // Collateral asset is split between liquidator and borrower. Priority to liquidator.
        uint256 rewardCollAmount = getRewardCollAmount(agreement);
        if (agreement.collAmount < rewardCollAmount) rewardCollAmount = agreement.collAmount;
        // Reward goes direct to liquidator.
        if (rewardCollAmount > 0) {
            // d4e3bdb6: LibUtilsPublic.safeErc20Transfer(address,address,uint256)
            (bool success, ) = IPosition(agreement.position.addr).passThrough(
                payable(address(LibUtilsPublic)),
                abi.encodeWithSelector(
                    LibUtilsPublic.safeErc20Transfer.selector,
                    agreement.collAsset.addr,
                    sender,
                    rewardCollAmount
                ),
                true
            );
            require(success, "Failed send coll to liquidator");
        }
        // Spare collateral goes back to borrower.
        if (agreement.collAmount > rewardCollAmount) {
            _loadFromPosition(
                position,
                agreement.borrowerAccount,
                agreement.collAsset,
                agreement.collAmount - rewardCollAmount
            );
        }

        /**
         * Loan Asset *
         */

        uint256 closeAmount;
        if (closePosition) {
            closeAmount = position.close(sender, agreement);
        } else {
            // SECURITY - what happens to erc20 transfer if amount is 0?
            closeAmount = position.getCloseAmount(agreement.position.parameters);
        }
        // Split loan asset in position between lender and borrower. Lender gets priority.
        (Asset memory costAsset, uint256 cost) = IAssessor(agreement.assessor.addr).getCost(agreement, closeAmount);
        uint256 lenderOwed = agreement.loanAmount;
        if (LibUtils.isValidLoanAssetAsCost(agreement.loanAsset, costAsset)) {
            lenderOwed += cost;
        } else if (costAsset.standard == ETH_STANDARD) {
            require(msg.value == cost, "_liquidate: value mismatch");
            IAccount(agreement.lenderAccount.addr).loadFromPosition{value: cost}(
                costAsset,
                cost,
                agreement.lenderAccount.parameters
            );
        }
        // SECURITY are these else revert checks necessary?
        else {
            revert("_liquidate: invalid cost asset");
        }
        // Call distribute after handling collateral assets in case collateral asset is same as loan asset.
        position.distribute(sender, lenderOwed, agreement);

        position.transferContract(sender);

        emit Liquidated(agreement.position.addr, sender);
    }

    // NOTE could this be improved by doing sideLoad in bookkeeper (w/o knowledge of asset handling) and then having
    //      bookkeeper report Asset(s) and Loaded amount(s) at kick time?  Trusted bookkeeper sideload reduces # of
    //      asset transfers by 1 per asset.
    /// @notice Load assets from position to an account.
    function _loadFromPosition(
        IPosition position,
        ModuleReference memory account,
        Asset memory asset,
        uint256 amount
    ) private {
        (bool success, ) = position.passThrough(
            payable(asset.addr),
            abi.encodeWithSelector(IERC20.approve.selector, account.addr, amount),
            false
        );
        require(success, "Failed approve ERC20 spend");
        // SECURITY why does anyone involved in the agreement care if liquidator uses _loadFromPosition vs
        //          loadFromUser? It is basically passing up on ownership of account assets. A hostile liquidator
        //          implementation could then essentially siphon off assets in an account without loss by lender
        //          or borrower.
        (success, ) = position.passThrough(
            payable(account.addr),
            abi.encodeWithSelector(IAccount.loadFromPosition.selector, asset, amount, account.parameters),
            false
        );
        require(success, "Failed load from position");
    }

    /// @notice Returns amount of collateral asset that is due to the liquidator.
    /// @dev may return a number that is larger than the total collateral amount.
    function getRewardCollAmount(Agreement memory agreement) public view virtual returns (uint256 rewardCollAmount);

    function canHandleAssets(
        Asset calldata loanAsset,
        Asset calldata collAsset,
        bytes calldata
    ) external pure override returns (bool) {
        if (loanAsset.standard == ERC20_STANDARD && collAsset.standard == ERC20_STANDARD) return true;
        return false;
    }
}
