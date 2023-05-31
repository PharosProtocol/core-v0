// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {IPosition} from "src/interfaces/IPosition.sol";
import {PositionFactory} from "src/modules/position/PositionFactory.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {IAccount} from "src/interfaces/IAccount.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {Module} from "src/modules/Module.sol";
import {C} from "src/C.sol";
import "src/LibUtil.sol";

abstract contract Position is IPosition, PositionFactory, Module {
    event ControlTransferred(address previousController, address newController);

    constructor(address bookkeeperAddr) PositionFactory(bookkeeperAddr) {
        // _setupRole
        // _setupRole
    }

    function deploy(Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        override
        proxyExecution
        onlyRole(C.ADMIN_ROLE)
    {
        _deploy(asset, amount, parameters);
    }

    function _deploy(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;

    function exit(Agreement calldata agreement, bytes calldata parameters)
        external
        override
        proxyExecution
        onlyRole(C.ADMIN_ROLE)
    {
        _exit(agreement, parameters);
    }

    /// @notice Close position and distribute assets. Give borrower MPC control.
    /// @dev All asset management must be done within this call, else bk would need to have asset-specific knowledge.
    function _exit(Agreement calldata agreement, bytes calldata parameters) internal virtual;

    // function _transferLoanAsset(address payable to, Asset memory asset, uint256 amount) internal virtual;

    // AUDIT Hello auditors, pls gather around. This feels risky.
    function transferContract(address controller) external override proxyExecution onlyRole(C.ADMIN_ROLE) {
        // ADMIN_ROLE is not transferred to prevent hostile actors from 'reactivating' a position by setting the
        // controller back to the bookkeeper.
        // grantRole(LIQUIDATOR_ROLE, controller); // having a distinct liquidator role and controller role is a nicer abstraction, but has gas cost for no benefit.
        grantRole(C.ADMIN_ROLE, controller);
        renounceRole(C.ADMIN_ROLE, msg.sender);

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
        onlyRole(C.ADMIN_ROLE)
        returns (bool, bytes memory)
    {
        return destination.call{value: msg.value}(data);
    }
}
