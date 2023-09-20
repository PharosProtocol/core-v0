// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {C} from "src/libraries/C.sol";
import {ILiquidator} from "src/interfaces/ILiquidator.sol";
import {IPosition} from "src/interfaces/IPosition.sol";

abstract contract Liquidator is ILiquidator, AccessControl {
    // mapping(bytes32 => bool) internal liquidating;

    event Liquidation(address indexed liquidator, address indexed position);

    constructor(address bookkeeperAddr) {
        _setupRole(C.BOOKKEEPER_ROLE, bookkeeperAddr);
    }

    function _liquidate(address caller, Agreement calldata agreement) internal virtual {
        emit Liquidation(caller, agreement.position.addr);
    }
}
