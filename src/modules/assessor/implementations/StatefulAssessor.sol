// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Assessor} from "../Assessor.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import "src/LibUtil.sol";
import {C} from "src/C.sol";

/*
 * DynamicInterestAssessor is one possible implementation of an assessor. 
 * It determines its current interest rate and maintains state of what its last updated interest rate was. 
 */

// NOTE implement an update function? non stateful implementations can ignore it. update on position creation or on
//      account changes? or *both*

contract DynamicInterestAssessor is Assessor {
    struct Parameters {
        uint256 baseInterestRate;
        uint256 utilizationKinkRatio;
    }

    uint256 lastUpdated;
    uint256 lastInterestRate;
    mapping(uint256 => uint256) private cumulatives; // % owed from inception to now

    /// @notice Return the cost of a loan, from inception until now, quantified in the Loan Asset.
    function getCost(Agreement calldata agreement, uint256) external view override returns (uint256 amount) {
        uint256 cumulative = _getCumulative();
        uint256 deltaCumulative = cumulative - cumulatives[agreement.deploymentTime];
        return deltaCumulative * agreement.loanAmount / C.RATIO_FACTOR;
    }

    /// @dev changes to the account should be performed before calling this.
    function update(Agreement calldata agreement) external {
        Parameters memory params = abi.decode(agreement.assessor.parameters, (Parameters));
        IAccount lenderAccount = IAccount(agreement.lenderAccount.addr);
        cumulatives[block.now] = _getCumulative();
        lastInterestRate = _getRate(lenderAccount.getUtilizationRatio(agreement.loanAsset, agreement.loanParameters));
        lastUpdatedTimestamp = block.now;
    }

    function _getCumulative() private view returns (uint256) {
        return cumulatives[lastUpdated] + (block.now - lastUpdatedTimestamp) * lastInterestRate;
    }

    function _getRate(uint256 utilizationRatio) private view returns (uint256) {
        if (utilizationRatio <= params.utilizationKinkRatio) {
            return params.baseInterestRate;
        } else {
            return params.baseInterestRate + (utilizationRatio - params.utilizationKinkRatio) ** 2 / C.RATIO_FACTOR;
        }
    }

    // Although the assessor is not moving assets around, this assessment only makes sense with divisible assets.
    // Collateral asset is irrelevant.
    function canHandleAsset(Asset calldata asset, bytes calldata) external pure override returns (bool) {
        if (asset.standard == ERC20_STANDARD) return true;
        return false;
    }
}

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
