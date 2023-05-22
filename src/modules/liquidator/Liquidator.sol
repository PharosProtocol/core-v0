// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {C} from "src/C.sol";
import {ILiquidator} from "src/interfaces/ILiquidator.sol";
import {IComparableParameters} from "src/interfaces/IComparableParameters.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {Module} from "src/modules/Module.sol";

abstract contract Liquidator is ILiquidator, AccessControl, Module {
    // NOTE need a system to ensure the same "position" signed message cannot be double liquidated
    // mapping(bytes32 => bool) internal liquidating;

    constructor(address bookkeeperAddr) {
        _setupRole(C.CONTROLLER_ROLE, bookkeeperAddr); // Factory role set
    }

    function liquidate(Agreement memory agreement) external {
        require(
            IPosition(agreement.position.addr).hasRole(C.CONTROLLER_ROLE, address(this)),
            "Liquidator: not currently liquidating this position"
        );
        _liquidate(agreement);
        // IPosition(agreement.position.addr).transferContract(agreement.liquidator.addr);
    }

    function _liquidate(Agreement memory agreement) internal virtual;
}
