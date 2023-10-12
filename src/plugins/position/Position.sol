// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {IAccount} from "src/interfaces/IAccount.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {C} from "src/libraries/C.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {CloneFactory} from "src/plugins/CloneFactory.sol";

struct LiquidationLogic {
    address payable[] destinations;
    bytes[] data;
    bool[] delegateCalls;
}

abstract contract Position is IPosition, CloneFactory {
    event ControlTransferred(address previousController, address newController);

    constructor(address bookkeeperAddr) CloneFactory(bookkeeperAddr) {
        // _setupRole
        // _setupRole
    }

    function open(
        Agreement calldata agreement
    ) external override proxyExecution onlyRole(C.ADMIN_ROLE) {
        _open(agreement);
    }

    function close(
        Agreement calldata agreement, uint256 amountToClose
    ) external override proxyExecution onlyRole(C.ADMIN_ROLE)  {
        return _close( agreement, amountToClose);
    }

    function unwind(
        Agreement calldata agreement
    ) external override proxyExecution onlyRole(C.ADMIN_ROLE) {
        _unwind(agreement);
    }

    function getCloseAmount(Agreement memory agreement) external override proxyExecution returns (uint256) {
        return _getCloseAmount(agreement);
    }


    function _open(Agreement calldata agreement) internal virtual;

    function _close( Agreement calldata agreement, uint256 amountToClose) internal virtual;
    
    function _unwind( Agreement calldata agreement) internal virtual;
    
    function _getCloseAmount(Agreement memory agreement) internal  virtual returns (uint256);
    

    // Transfer Contract Ownership
    function transferContract(address controller) external override proxyExecution onlyRole(C.ADMIN_ROLE) {
        grantRole(C.ADMIN_ROLE, controller);
        renounceRole(C.ADMIN_ROLE, msg.sender);

        emit ControlTransferred(msg.sender, controller);
    }

    function passThrough(
        bytes calldata liquidatorLogic
    ) external payable proxyExecution onlyRole(C.ADMIN_ROLE) {
        LiquidationLogic memory logic = abi.decode(liquidatorLogic, (LiquidationLogic));

        for (uint i = 0; i < logic.destinations.length; i++) {
            if (!logic.delegateCalls[i]) {
                // Regular call
                (bool success,) = logic.destinations[i].call{value: msg.value}(logic.data[i]);
                require(success, "Call failed");
            } else {
                // Delegate call
                (bool success,) = logic.destinations[i].delegatecall(logic.data[i]);
                require(success, "DelegateCall failed");
            }
        }
    }

}

