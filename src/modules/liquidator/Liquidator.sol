// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {C} from "src/C.sol";
import {ILiquidator} from "src/interfaces/ILiquidator.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {Module} from "src/modules/Module.sol";

abstract contract Liquidator is ILiquidator, AccessControl, Module {
    // NOTE need a system to ensure the same "position" signed message cannot be double liquidated
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
