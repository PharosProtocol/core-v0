// SPDX-License-Identifier: MIT

/*
 * INVARIANTS:
 *   - getCost Return asset is ETH or ERC20.
 */

pragma solidity 0.8.19;

import {IAssessor} from "src/interfaces/IAssessor.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";

abstract contract Assessor is IAssessor {
    function getCost(
        Agreement calldata agreement,
        uint256 currentAmount
    ) external view returns (uint256 amount) {
        (amount) = _getCost(agreement, currentAmount);
        
    }

    function _getCost(
        Agreement calldata agreement,
        uint256 currentAmount
    ) internal view virtual returns (uint256 amount);
}
