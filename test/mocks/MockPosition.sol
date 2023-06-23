// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "src/libraries/LibUtil.sol";
import {Asset} from "src/libraries/LibUtil.sol";
import {Position} from "src/modules/position/Position.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";

contract MockPosition is Position {
    uint256 currentAmount;
    Asset positionAsset;

    constructor(address bookkeeperAddr) Position(bookkeeperAddr) {}

    function _deploy(Asset calldata asset, uint256 amount, bytes calldata) internal override {
        currentAmount = amount;
        positionAsset = asset;
    }

    function _getCloseAmount(bytes calldata) internal view override returns (uint256) {
        return currentAmount;
    }

    function _close(address sender, Agreement calldata agreement, bool distribute, bytes calldata)
        internal
        override
        returns (uint256 closedAmount)
    {
        uint256 lenderOwed = agreement.loanAmount + IAssessor(agreement.assessor.addr).getCost(agreement, closedAmount);

        if (lenderOwed > currentAmount) {
            // Lender is owed more than the position is worth.
            // Sender pays the difference.
            Utils.safeErc20TransferFrom(agreement.loanAsset.addr, sender, address(this), lenderOwed - currentAmount);
        }

        require(distribute == false, "MockPosition: distribute not supported");

        return currentAmount;
    }

    function canHandleAsset(Asset calldata, bytes calldata) external pure override returns (bool) {
        return true;
    }

    // function _transferLoanAsset(address payable to, Asset memory asset, uint256 amount) internal override {}
}
