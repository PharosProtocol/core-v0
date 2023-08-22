// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAccount} from "src/interfaces/IAccount.sol";
import {C} from "src/libraries/C.sol";
import {Position} from "src/plugins/position/Position.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";

import {Asset, ERC20_STANDARD, LibUtils} from "src/libraries/LibUtils.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";

/*
 * Send assets directly to a user wallet. Used with overcollateralized loans.
 */

// NOTE collateralized positions are not explicitly blocked. UI/user should take care.

contract WalletFactory is Position {
    struct Parameters {
        address recipient;
    }

    uint256 public walletAmount;

    constructor(address bookkeeperAddr) Position(bookkeeperAddr) {}

    function _getCloseAmount(bytes calldata parameters) internal view override returns (uint256) {
        return walletAmount;
    }

    /// @dev assumes assets are already in Position.
    function _deploy(Agreement calldata agreement) internal override {
        Parameters memory params = abi.decode(agreement.position.parameters, (Parameters));
        walletAmount = agreement.loanAmount;
        push(
            params.recipient,
            agreement.loanFreighter,
            agreement.loanAsset,
            agreement.loanAmount,
            AssetState.TERMINAL_LOAN
        );
    }

    // NOTE drew - was prev handling short amount here in impl, but should now bubble it up to bk
    function _close(Agreement calldata agreement) internal override returns (uint256 closedAmount) {
        Parameters memory params = abi.decode(agreement.position.parameters, (Parameters));

        // // Positions do not typically factor in a cost, but doing so here often saves an ERC20 transfer in distribute.
        // (Asset memory costAsset, uint256 cost) = IAssessor(agreement.assessor.addr).getCost(agreement, walletAmount);
        // if (LibUtils.isValidLoanAssetAsCost(agreement.loanAsset, costAsset)) {
        //     returnAmount += cost;
        // }

        // Borrower must have pre-approved use of erc20.
        pull(
            params.recipient,
            agreement.loanFreighter,
            agreement.loanAsset,
            agreement.loanAmount,
            AssetState.TERMINAL_LOAN
        );

        return agreement.loanAmount;
    }

    // Public Helpers.
}
