// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.19;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {IAccount} from "src/interfaces/IAccount.sol";
// import {C} from "src/libraries/C.sol";
// import {Position} from "src/plugins/position/Position.sol";
// import {IAssessor} from "src/interfaces/IAssessor.sol";
// import {Agreement} from "src/libraries/LibBookkeeper.sol";
// import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";

// /*
//  * Send assets directly to a user wallet. Used with overcollateralized loans.
//  */

// // NOTE collateralized positions are not explicitly blocked. UI/user should take care.

// contract WalletFactory is Position {
//     struct Parameters {
//         address recipient;
//     }

//     uint256 public amountDistributed;

//     constructor(address protocolAddr) Position(protocolAddr) {}


//     /// @dev assumes assets are already in Position.
//     function _deploy(Agreement calldata agreement) internal override {
//         Parameters memory params = abi.decode(agreement.borrowerAccount.owner, (Parameters));
//         amountDistributed = amount;
//         LibUtilsPublic.safeErc20Transfer(agreement., params.recipient, amountDistributed);
//     }

//     function _close(address sender, Agreement calldata agreement) internal override returns (uint256 closedAmount) {
//         uint256 returnAmount = amountDistributed;

//         // Positions do not typically factor in a cost, but doing so here often saves an ERC20 transfer in distribute.
//         (bytes memory costAsset, uint256 cost) = IAssessor(agreement.assessor.addr).getCost(
//             agreement,
//             amountDistributed
//         );
//             returnAmount += cost;
        

//         // Borrower must have pre-approved use of erc20.
//         LibUtilsPublic.safeErc20TransferFrom(agreement.loanAsset.addr, sender, address(this), returnAmount);

//         return amountDistributed;
//     }

//     function _distribute(address sender, uint256 lenderAmount, Agreement calldata agreement) internal override {
//         IERC20 erc20 = IERC20(agreement.loanAsset.addr);
//         uint256 balance = erc20.balanceOf(address(this));

//         // If there are not enough assets to pay lender, pull missing from sender.
//         if (lenderAmount > balance) {
//             LibUtilsPublic.safeErc20TransferFrom(
//                 agreement.loanAsset.addr,
//                 sender,
//                 address(this),
//                 lenderAmount - balance
//             );
//         }

//         if (lenderAmount > 0) {
//             erc20.approve(agreement.lenderAccount.addr, lenderAmount);
//             IAccount(agreement.lenderAccount.addr).loadFromPosition(
//                 agreement.loanAsset,
//                 lenderAmount,
//                 agreement.lenderAccount.parameters
//             );
//         }
//     }

//     // Public Helpers.

//     function _getCloseAmount(bytes calldata) internal view override returns (uint256) {
//         return amountDistributed;
//     }
// }
