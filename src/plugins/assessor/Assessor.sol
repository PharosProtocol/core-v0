// SPDX-License-Identifier: MIT

/*
 * INVARIANTS:
 *   - getCost Return asset is ETH or ERC20.
 */

pragma solidity 0.8.19;

import {IAssessor} from "src/interfaces/IAssessor.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset, ETH_STANDARD, ERC20_STANDARD} from "src/libraries/LibUtils.sol";

abstract contract Assessor is IAssessor {
    function getCost(
        Agreement calldata agreement,
        uint256 currentAmount
    ) external view returns (Asset memory asset, uint256 amount) {
        (asset, amount) = _getCost(agreement, currentAmount);
        // Invariant check.
        require(asset.standard == ETH_STANDARD || asset.standard == ERC20_STANDARD, "getCost: invalid asset");
    }

    function _getCost(
        Agreement calldata agreement,
        uint256 currentAmount
    ) internal view virtual returns (Asset memory asset, uint256 amount);
}
