// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {IAccount} from "src/interfaces/IAccount.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {C} from "src/libraries/C.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset} from "src/libraries/LibUtils.sol";
import {AssetHolder} from "src/plugins/AssetHolder.sol";

// Implementation should not allow user to enter a position in such a way that they
// would be unable to exit. Lender does not necessarily agree to the parameters, so they
// cannot be configured in any way that would allow locking of assets. Griefing.
// TODO SECURITY this is probably possible in current Uni Hold Position impl. Need to verify exit
// path at enter time.

abstract contract Position is IPosition, AssetHolder {
    event ControlTransferred(address previousController, address newController);

    constructor(address bookkeeperAddr) AssetHolder(bookkeeperAddr, category) {}

    /// @notice Do nothing.
    function _initialize(bytes calldata initData) internal override {}

    function getCloseAmount(bytes calldata parameters) external view override proxyExecution returns (uint256) {
        return _getCloseAmount(parameters);
    }

    function deploy(Agreement calldata agreement) external override proxyExecution onlyRole(C.CONTROLLER_ROLE) {
        _deploy(agreement);
    }

    function close(
        address sender,
        Agreement calldata agreement
    ) external override proxyExecution onlyRole(C.CONTROLLER_ROLE) returns (uint256) {
        return _close(sender, agreement);
    }

    // function distribute(
    //     address to,
    //     PluginRef calldata freighter,
    //     Asset calldata asset,
    //     uint256 amount,
    //     AssetState calldata fromState,
    //     bytes calldata parameters
    // ) external payable override proxyExecution onlyRole(C.CONTROLLER_ROLE) {
    //     _distribute(to, freighter, asset, amount, fromState, parameters);
    //     push(to, freighter, asset, amount, fromState, parameters);
    // }

    function _getCloseAmount(bytes calldata parameters) internal view virtual returns (uint256);

    function _deploy(Agreement calldata agreement) internal virtual;

    function _close(address sender, Agreement calldata agreement) internal virtual returns (uint256);

    // function _distribute(
    //     address to,
    //     PluginRef calldata freighter,
    //     Asset calldata asset,
    //     uint256 amount,
    //     AssetState calldata fromState,
    //     bytes calldata parameters
    // ) internal virtual;

    // SECURITY Hello auditors. This feels risky.
    function transferContract(address controller) external override proxyExecution onlyRole(C.CONTROLLER_ROLE) {
        _grantRole(C.CONTROLLER_ROLE, controller);
        _revokeRole(C.CONTROLLER_ROLE, msg.sender);

        emit ControlTransferred(msg.sender, controller);
    }

    // SECURITY Hello auditors. This also is a point of risk.
    function passThrough(
        address payable destination,
        bytes calldata data,
        bool delegateCall
    ) external payable proxyExecution onlyRole(C.CONTROLLER_ROLE) returns (bool, bytes memory) {
        if (!delegateCall) {
            return destination.call{value: msg.value}(data);
        } else {
            return destination.delegatecall(data);
        }
    }
}
