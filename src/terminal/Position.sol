// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {IPosition} from "src/terminal/IPosition.sol";
import {Terminal} from "src/terminal/Terminal.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {IAccount} from "src/modules/account/IAccount.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IAssessor} from "src/modules/assessor/IAssessor.sol";
import {C} from "src/C.sol";
import "src/LibUtil.sol";

abstract contract Position is Terminal, IPosition {
    event ControlTransferred(address previousController, address newController);

    constructor(address bookkeeperAddr) Terminal(bookkeeperAddr) {}

    function deploy(Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        override
        proxyExecution
        onlyRole(C.CONTROLLER_ROLE)
    {
        _deploy(asset, amount, parameters);
    }

    function _deploy(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;

    function exit(Agreement calldata agreement, bytes calldata parameters)
        external
        override
        proxyExecution
        onlyRole(C.CONTROLLER_ROLE)
    {
        _exit(agreement, parameters);
    }

    /// @notice Close position and distribute assets. Give borrower MPC control.
    /// @dev All asset management must be done within this call, else bk would need to have asset-specific knowledge.
    function _exit(Agreement calldata agreement, bytes calldata parameters) internal virtual;

    // function _transferLoanAsset(address payable to, Asset memory asset, uint256 amount) internal virtual;

    // AUDIT Hello auditors, pls gather around. This feels risky.
    function transferContract(address controller) external override proxyExecution onlyRole(C.CONTROLLER_ROLE) {
        // grantRole(LIQUIDATOR_ROLE, controller); // having a distinct liquidator role and controller role is a nicer abstraction, but has gas cost for no benefit.
        grantRole(C.CONTROLLER_ROLE, controller);
        renounceRole(C.CONTROLLER_ROLE, address(this));

        // TODO fix this so that admin role is not granted to untrustable code (liquidator user or module). Currently
        // will get stuck as liquidator module will not be able to grant liquidator control.
        // Do not allow liquidators admin access to avoid security implications if set back to protocol control.
        // if (grantAdmin) {
        //     grantRole(DEFAULT_ADMIN_ROLE, controller);
        // }
        // renounceRole(DEFAULT_ADMIN_ROLE);
        emit ControlTransferred(msg.sender, controller);
    }

    function passThrough(address payable destination, bytes calldata data)
        external
        payable
        proxyExecution
        onlyRole(C.CONTROLLER_ROLE)
        returns (bool, bytes memory)
    {
        return destination.call{value: msg.value}(data);
    }
}
