// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAccount} from "src/interfaces/IAccount.sol";
import {C} from "src/libraries/C.sol";
import {Position} from "src/modules/position/Position.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";

import {Asset, ERC20_STANDARD, LibUtils} from "src/libraries/LibUtils.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";

contract WalletFactory is Position {
    struct Parameters {
        address recipient;
    }

    uint256 public amountDistributed;

    constructor(address protocolAddr) Position(protocolAddr) {}

    function canHandleAsset(Asset calldata asset, bytes calldata) external pure override returns (bool) {
        if (asset.standard != ERC20_STANDARD) return false;
        return true;
    }

    /// @dev assumes assets are already in Position.
    function _deploy(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        amountDistributed = amount;
        LibUtilsPublic.safeErc20Transfer(asset.addr, params.recipient, amountDistributed);
    }

    function _close(address sender, Agreement calldata agreement) internal override returns (uint256 closedAmount) {
        uint256 returnAmount = amountDistributed;

        // Positions do not typically factor in a cost, but doing so here often saves an ERC20 transfer in distribute.
        (Asset memory costAsset, uint256 cost) = IAssessor(agreement.assessor.addr).getCost(
            agreement,
            amountDistributed
        );
        if (LibUtils.isValidLoanAssetAsCost(agreement.loanAsset, costAsset)) {
            returnAmount += cost;
        }

        // Borrower must have pre-approved use of erc20.
        LibUtilsPublic.safeErc20TransferFrom(agreement.loanAsset.addr, sender, address(this), returnAmount);

        return amountDistributed;
    }

    function _distribute(address sender, uint256 lenderAmount, Agreement calldata agreement) internal override {
        IERC20 erc20 = IERC20(agreement.loanAsset.addr);
        uint256 balance = erc20.balanceOf(address(this));

        // If there are not enough assets to pay lender, pull missing from sender.
        if (lenderAmount > balance) {
            LibUtilsPublic.safeErc20TransferFrom(
                agreement.loanAsset.addr,
                sender,
                address(this),
                lenderAmount - balance
            );
        }

        if (lenderAmount > 0) {
            erc20.approve(agreement.lenderAccount.addr, lenderAmount);
            IAccount(agreement.lenderAccount.addr).loadFromPosition(
                agreement.loanAsset,
                lenderAmount,
                agreement.lenderAccount.parameters
            );
        }
    }

    // Public Helpers.

    function _getCloseAmount(bytes calldata) internal view override returns (uint256) {
        return amountDistributed;
    }

    // function validParameters(bytes calldata) private pure returns (bool) {
    //     return true;
    //     // NOTE somewhere in here should block under collateralized positions. right?
    // }

    // function AssetParameters(Asset asset) private view {
    //     require(asset.standard == ERC20_STANDARD);
    //     require(asset.addr == path[0th token]);
    // require paths to be compatible so no assets get stuck
    // (,address finalAssetAddr,) = params.exitPath.decodeFirstPool();
    // require(asset.addr == finalAssetAddr, "illegal exit path");
    // }
}
