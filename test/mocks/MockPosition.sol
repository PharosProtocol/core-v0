// SPDX-License-Identifier: MIT
// solhint-disable

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Asset, ERC20_STANDARD, LibUtils} from "src/libraries/LibUtils.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";
import {Position} from "src/modules/position/Position.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {IAccount} from "src/interfaces/IAccount.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";

contract MockPosition is Position {
    uint256 public currentAmount;
    Asset public positionAsset;

    constructor(address bookkeeperAddr) Position(bookkeeperAddr) {}

    function _deploy(Asset calldata asset, uint256 amount, bytes calldata) internal override {
        currentAmount = amount;
        positionAsset = asset;
    }

    function _getCloseAmount(bytes calldata) internal view override returns (uint256) {
        return currentAmount;
    }

    function _close(address, Agreement calldata agreement) internal view override returns (uint256 closedAmount) {
        (Asset memory costAsset, ) = IAssessor(agreement.assessor.addr).getCost(agreement, closedAmount);
        require(LibUtils.isValidLoanAssetAsCost(agreement.loanAsset, costAsset), "_close(): cost asset invalid");

        return currentAmount;
    }

    function _distribute(address sender, uint256 lenderAmount, Agreement calldata agreement) internal override {
        IERC20 erc20 = IERC20(agreement.loanAsset.addr);
        uint256 balance = erc20.balanceOf(address(this));

        if (lenderAmount > balance) {
            // Lender is owed more than the position is worth.
            // Sender pays the difference.
            LibUtilsPublic.safeErc20TransferFrom(
                agreement.loanAsset.addr,
                sender,
                address(this),
                lenderAmount - balance
            );
            balance += lenderAmount - balance;
        }

        if (lenderAmount > 0) {
            erc20.approve(agreement.lenderAccount.addr, lenderAmount);
            IAccount(agreement.lenderAccount.addr).loadFromPosition(
                agreement.loanAsset,
                lenderAmount,
                agreement.lenderAccount.parameters
            );
            balance -= lenderAmount;
        }

        if (balance > 0) {
            erc20.approve(agreement.borrowerAccount.addr, balance);
            IAccount(agreement.borrowerAccount.addr).loadFromPosition(
                agreement.loanAsset,
                balance,
                agreement.borrowerAccount.parameters
            );
        }
    }

    function canHandleAsset(Asset calldata, bytes calldata) external pure override returns (bool) {
        return true;
    }

    // function _transferLoanAsset(address payable to, Asset memory asset, uint256 amount) internal override {}
}
