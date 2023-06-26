// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "forge-std/console.sol";

import {IAccount} from "src/interfaces/IAccount.sol";
import {C} from "src/libraries/C.sol";
import {Position} from "src/modules/position/Position.sol";
import {Module} from "src/modules/Module.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "src/libraries/LibUtil.sol";

contract WalletFactory is Position {
    struct Parameters {
        address recipient;
    }

    uint256 amountDistributed;

    constructor(address protocolAddr) Position(protocolAddr) {}

    function canHandleAsset(Asset calldata asset, bytes calldata) external pure override returns (bool) {
        if (asset.standard != ERC20_STANDARD) return false;
        return true;
    }

    /// @dev assumes assets are already in Position.
    function _deploy(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        amountDistributed = amount;
        Utils.safeErc20Transfer(asset.addr, params.recipient, amountDistributed);
    }

    function _close(address sender, Agreement calldata agreement, bool distribute, bytes calldata)
        internal
        override
        returns (uint256 closedAmount)
    {
        // console.log(IERC20(params.exitPath
        uint256 lenderOwed =
            agreement.loanAmount + IAssessor(agreement.assessor.addr).getCost(agreement, amountDistributed);
        // Borrower must have pre-approved use of erc20.
        Utils.safeErc20TransferFrom(agreement.loanAsset.addr, sender, address(this), lenderOwed);

        if (distribute) {
            IERC20(agreement.loanAsset.addr).approve(agreement.lenderAccount.addr, lenderOwed);
            // SECURITY account assets of non-involved parties are at risk if a position uses
            //          loadFromUser rathe than loadFromPosition.
            IAccount(agreement.lenderAccount.addr).loadFromPosition(
                agreement.loanAsset, lenderOwed, agreement.lenderAccount.parameters
            );
        }
        // Collateral is still in borrower account and is unlocked by the bookkeeper.
        return amountDistributed;
    }

    // Public Helpers.

    function _getCloseAmount(bytes calldata) internal view override returns (uint256) {
        return amountDistributed;
    }

    function validParameters(bytes calldata) private pure returns (bool) {
        return true;
        // NOTE somewhere in here should block under collateralized positions. right?
    }

    // function AssetParameters(Asset asset) private view {
    //     require(asset.standard == ERC20_STANDARD);
    //     require(asset.addr == path[0th token]);
    // require paths to be compatible so no assets get stuck
    // (,address finalAssetAddr,) = params.exitPath.decodeFirstPool();
    // require(asset.addr == finalAssetAddr, "illegal exit path");
    // }
}
