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

    function _close( address sender, Agreement calldata agreement, uint256 amountToClose) internal override  {

        Asset memory loanAsset = abi.decode(agreement.loanAsset, (Asset));
        Asset memory collAsset = abi.decode(agreement.collAsset, (Asset));

        IERC20 loanERC20 = IERC20(loanAsset.addr);
        IERC20 collERC20 = IERC20(collAsset.addr);

        uint256 balance = loanERC20.balanceOf(address(this));

        // If there are not enough assets to pay lender, pull missing from sender.
        if (amountToClose > balance) {
            LibUtilsPublic.safeErc20TransferFrom(
                loanAsset.addr,
                sender,
                address(this),
                amountToClose - balance
            );
        }

        if (amountToClose > 0) {
            loanERC20.approve(agreement.lenderAccount.addr, amountToClose);
            IAccount(agreement.lenderAccount.addr).loadFromPosition(
                agreement.loanAsset,
                amountToClose,
                agreement.lenderAccount.parameters
            );

        }

        uint256 adjCollAmount = (agreement.collAmount * 10**(collAsset.decimals))/C.RATIO_FACTOR;
        //LibUtilsPublic.safeErc20Transfer(collAssetAddress, sender, adjCollAmount);

        collERC20.approve(agreement.borrowerAccount.addr, adjCollAmount);
        
        IAccount(agreement.borrowerAccount.addr).loadFromPosition(
                agreement.collAsset,
                agreement.collAmount,
                agreement.borrowerAccount.parameters
            );

    }

    // Public Helpers.

    function _getCloseAmount(Agreement calldata agreement) internal view override returns (uint256) {
        
        Asset memory collAsset = abi.decode(agreement.collAsset, (Asset));
        address collAssetAddress = collAsset.addr;
        uint8 collAssetDecimals = collAsset.decimals;

        IERC20 erc20 = IERC20(collAssetAddress);
        uint256 balance = erc20.balanceOf(address(this));
        uint256 closeAmount= balance * IOracle(agreement.collOracle.addr).getOpenPrice(agreement.collOracle.parameters)/10**(collAssetDecimals) ;
        
        return closeAmount;
    }
}
