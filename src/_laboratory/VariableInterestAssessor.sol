// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Assessor} from "src/modules/assessor/Assessor.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import "src/libraries/LibUtils.sol";
import {C} from "src/libraries/C.sol";

/*
 * VariableInterestAssessor is one possible implementation of an assessor. 
 * It determines cost by using account time-weighted average utilization rate. Accounts are responsible for tracking
 * their own utilization rate over time. This dynamic rate design allows for loans with variable interest rates.
 * Notable limitation of implementations:
 *   - Accounts need to be able to report twa utilization rate
 */

// NOTE probably want something more complex than flat interest under kink. Also more complex than exponential
//      above kink. Mod will probably have ideas.
// NOTE that utilization kink here may not behave as one would expect. Since we are using the average utilization,
//      a period of high utilization that does not push average above the kink will not be subject to the high
//      cost penalty.

// abstract contract VariableInterestAssessor is Assessor {
//     struct Parameters {
//         uint256 baseInterestRate;
//         uint256 utilizationKinkRatio;
//     }

//     /// @notice Return the cost of a loan, from inception until now, quantified in the Loan Asset.
//     function getCost(Agreement calldata agreement, uint256) external view override returns (uint256 amount) {
//         uint256 twaUtilization = IAccount(agreement.lenderAccount.addr).getTWAUtilization(
//             agreement.loanAsset, agreement.deploymentTime, agreement.lenderAccount.parameters
//         );
//         uint256 effectiveInterestRate;
//         if (twaUtilization <= params.utilizationKinkRatio) {
//             effectiveInterestRate = params.baseInterestRate;
//         } else {
//             effectiveInterestRate = params.baseInterestRate
//                 + (C.RATIO_FACTOR + (twaUtilization - params.utilizationKinkRatio)) ** 2 / C.RATIO_FACTOR;
//         }
//         return effectiveInterestRate * agreement.loanAmount / C.RATIO_FACTOR;
//     }

//     function _getCumulative() private view returns (uint256) {
//         return cumulatives[lastUpdated] + (block.timestamp - lastUpdated) * lastInterestRate;
//     }

//     function _getRate(uint256 utilizationRatio, Parameters memory params) private view returns (uint256) {
//         if (utilizationRatio <= params.utilizationKinkRatio) {
//             return params.baseInterestRate;
//         } else {
//             return params.baseInterestRate + (utilizationRatio - params.utilizationKinkRatio) ** 2 / C.RATIO_FACTOR;
//         }
//     }

//     // Although the assessor is not moving assets around, this assessment only makes sense with divisible assets.
//     // Collateral asset is irrelevant.
//     function canHandleAsset(Asset calldata asset, bytes calldata) external pure override returns (bool) {
//         if (asset.standard == ERC20_STANDARD) return true;
//         return false;
//     }
// }

/*
Attempting to get current value to attribute to suppliers is fundamentally different than something like other protocols bc there is not a single or set number of places to look for outstanding interest / cost. instead there is
an arbitrary number of outstanding agreements that are not present at call time. It is seeming likely that it will not
be possible to implement a dynamic interest rate in the same fashion that large markets currently use.

May be possible if an account was limited to one order, utilization was retrievable with last updated timestamp, and
the order had determinable cost. This require the account to make assumptions about its configuration though. This 
gives variable supply apy. No effect on borrow rate.
Variable borrow rate can be achieved by storing an array of rates in the assessor. At close take time weighted average
of rates. Seems hella costly, maybe can be done with cumulative math instead. 
*/
