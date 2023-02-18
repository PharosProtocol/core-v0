// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "src/modulus/C.sol";
import "src/modulus/OfferAccount.sol";
import "src/modulus/RequestAccount.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

struct Position {
    bytes32 offerAccount;
    bytes32 requestAccount;
    bytes32 termSheet;
    address terminal;
    address loanAsset;
    uint256 loanAmount;
    address collateralAsset;
    uint256 collateralAmount;
    uint256 enterBlockTime;
}

// contract PositionRegistry {
//     Position[] private positions;

//     OfferAccountRegistry oar;
//     RequestAccountRegistry rar;

//     /*
//     Create a new position from a compatible Offer Account and Request Account.
//     Any user can create any position, as long as it is allow by both the Offer and Request account.
//     */
//     function createPosition(
//         bytes32 id,
//         bytes32 offerAccount,
//         bytes32 requestAccount,
//         bytes32 termSheet,
//         address loanAsseet,
//         address collateralAsset
//     ) public {
//         Position storage position = positions[id];
//         require(position.loanAsset != address(0));
//         position.offerAccount = offerAccount;
//         position.requestAccount = requestAccount;
//         position.termSheet = termSheet;
//         // position.loanAsset = rar.accounts[requestAccount].requestedAsset;
//         // NOTE: Do we want to do checks here to confirm matchmake is valid? Or at offer/request account creation?
//         // check collateralization ratio, asset:terminal match, etc
//         // Likely want to check it here, which will enable dynamic allowlisting of Term Sheets.
//         // // Check Offer validity.
//         // // Check Request validity.

//         // NOTE: gas optimization: lots of lookups, memory storage of variables, or struct copy?

//         // Loan amount is min between offer amount and request amount of given asset.
//         position.loanAmount = oar.getBalance(offerAccount, loanAsseet) < rar.getRequestedAmount(requestAccount)
//             ? oar.getBalance(offerAccount)
//             : rar.getRequestedAmount(requestAccount);

//         position.collateralAmount =
//             position.loanAmount * rar.accounts[requestAccount].collateralizationRatio / C.RATIO_BASE; // idk how this should work actually

//         require(oar.isAllowedBorrower(rar.getBorrower(position.requestAccount)));
//         require(oar.isAllowedTermSheet(position.termSheet));
//         require(oar.getBalance(loanAsseet) >= position.enterAmount);
//     }
// }
