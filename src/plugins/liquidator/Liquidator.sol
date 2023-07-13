// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {C} from "src/libraries/C.sol";
import {ILiquidator} from "src/interfaces/ILiquidator.sol";
import {IPosition} from "src/interfaces/IPosition.sol";

abstract contract Liquidator is ILiquidator, AccessControl {
    // mapping(bytes32 => bool) internal liquidating;

    event KickReceived(address indexed position, Agreement agreement, address kicker);
    event Liquidated(address indexed position, address indexed liquidator);

    constructor(address bookkeeperAddr) {
        _setupRole(C.BOOKKEEPER_ROLE, bookkeeperAddr);
    }

    function receiveKick(address kicker, Agreement calldata agreement) external onlyRole(C.BOOKKEEPER_ROLE) {
        _receiveKick(kicker, agreement);
        emit KickReceived(agreement.position.addr, agreement, kicker);
    }

    function _receiveKick(address kicker, Agreement calldata agreement) internal virtual;
}
