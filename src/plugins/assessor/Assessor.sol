// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IAssessor} from "src/interfaces/IAssessor.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";

abstract contract Assessor is IAssessor {
    function getCost(
        Agreement calldata agreement
    ) external view returns (uint256 amount) {
        (amount) = _getCost(agreement);
        
    }

    function _getCost(
        Agreement calldata agreement
    ) internal view virtual returns (uint256 amount);
}
