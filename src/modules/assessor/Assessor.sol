// SPDX-License-Identifier: UNLICENSED

/*
 * INVARIANTS:
 *   - getCost Return asset is ETH or ERC20.
 */

pragma solidity 0.8.19;

import {IAssessor} from "src/interfaces/IAssessor.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset, ETH_STANDARD, ERC20_STANDARD} from "src/libraries/LibUtils.sol";
import {Module} from "src/modules/Module.sol";

abstract contract Assessor is IAssessor, Module {
    function getCost(Agreement calldata agreement, uint256 currentAmount)
        external
        view
        returns (Asset memory asset, uint256 amount)
    {
        (asset, amount) = _getCost(agreement, currentAmount);
        // Invariant check.
        require(asset.standard == ETH_STANDARD || asset.standard == ERC20_STANDARD, "getCost: invalid asset");
    }

    function _getCost(Agreement calldata agreement, uint256 currentAmount)
        internal
        view
        virtual
        returns (Asset memory asset, uint256 amount);
}
