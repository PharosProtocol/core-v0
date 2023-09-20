// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAccount} from "src/interfaces/IAccount.sol";
import {C} from "src/libraries/C.sol";
import {Position} from "src/plugins/position/Position.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";
import {IOracle} from "src/interfaces/IOracle.sol";


/*
 * Send assets directly to a user wallet. Used with no leverage loans.
 */

// NOTE leverage loans are not explicitly blocked. UI/user should take care.

contract WalletFactory is Position {
    struct Parameters {
        address recipient;
    }


    constructor(address protocolAddr) Position(protocolAddr) {}

    // another way to get recipient directly msg.sender == IAccount(agreement.borrowerAccount.addr).getOwner(agreement.borrowerAccount.parameters),
    struct Asset {
        address addr;
        uint8 decimals;
    }
    /// @dev assumes assets are already in Position.
    function _open(Agreement calldata agreement) internal override {
        Parameters memory params = abi.decode(agreement.position.parameters, (Parameters));
        Asset memory loanAsset = abi.decode(agreement.loanAsset, (Asset));
        LibUtilsPublic.safeErc20Transfer(loanAsset.addr, params.recipient, agreement.loanAmount);

    }

    function _close( address sender, Agreement calldata agreement) internal override  {

        uint256 cost = IAssessor(agreement.assessor.addr).getCost(agreement);
        uint256 closeAmount = agreement.loanAmount + cost * C.RATIO_FACTOR/ IOracle(agreement.loanOracle.addr).getOpenPrice( agreement.loanOracle.parameters);
        address loanAssetAddress = abi.decode(agreement.loanAsset, (address));
        Asset memory collAsset = abi.decode(agreement.collAsset, (Asset));
        address collAssetAddress = collAsset.addr;
        uint256 collAssetDecimal = collAsset.decimals;


        IERC20 erc20 = IERC20(loanAssetAddress);
        uint256 balance = erc20.balanceOf(address(this));

        // If there are not enough assets to pay lender, pull missing from sender.
        if (closeAmount > balance) {
            LibUtilsPublic.safeErc20TransferFrom(
                loanAssetAddress,
                sender,
                address(this),
                closeAmount - balance
            );
        }

        if (closeAmount > 0) {
            erc20.approve(agreement.lenderAccount.addr, closeAmount);
            IAccount(agreement.lenderAccount.addr).loadFromPosition(
                agreement.loanAsset,
                closeAmount,
                agreement.lenderAccount.parameters
            );

        }
        uint256 convertedAmount = agreement.collAmount * 10**(collAssetDecimal)/C.RATIO_FACTOR;

        LibUtilsPublic.safeErc20Transfer(collAssetAddress, sender, convertedAmount);


    }

    // Public Helpers.

    function _getCloseValue(Agreement calldata agreement) internal view override returns (uint256) {
        uint256 value= agreement.collAmount * IOracle(agreement.collOracle.addr).getOpenPrice( agreement.collOracle.parameters)/C.RATIO_FACTOR ;
        return value;
    }
}
