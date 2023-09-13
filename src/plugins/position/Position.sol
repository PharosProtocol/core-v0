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

// Implementation should not allow user to enter a position in such a way that they
// would be unable to exit. Lender does not necessarily agree to the parameters, so they
// cannot be configured in any way that would allow locking of assets. Griefing.
// TODO SECURITY this is probably possible in current Uni Hold Position impl. Need to verify exit
// path at enter time.

abstract contract Position is IPosition, CloneFactory {
    event ControlTransferred(address previousController, address newController);

    constructor(address bookkeeperAddr) CloneFactory(bookkeeperAddr) {
        // _setupRole
        // _setupRole
    }

    function deploy(
        bytes calldata assetData,
        uint256 amount,
        bytes calldata parameters
    ) external override proxyExecution onlyRole(C.ADMIN_ROLE) {
        _deploy(assetData, amount, parameters);
    }

    function _deploy(bytes calldata assetData, uint256 amount, bytes calldata parameters) internal virtual;

    function close(
        address sender,
        Agreement calldata agreement
    ) external override proxyExecution onlyRole(C.ADMIN_ROLE) returns (uint256) {
        return _close(sender, agreement);
    }

    function distribute(
        address sender,
        uint256 lenderAmount,
        Agreement calldata agreement
    ) external payable override proxyExecution onlyRole(C.ADMIN_ROLE) {
        return _distribute(sender, lenderAmount, agreement);
    }

    function getCloseAmount(bytes calldata parameters) external view override proxyExecution returns (uint256) {
        return _getCloseAmount(parameters);
    }

    /// @notice Close position and distribute assets. Give borrower MPC control.
    /// @dev All asset management must be done within this call, else bk would need to have asset-specific knowledge.
    function _close(address sender, Agreement calldata agreement) internal virtual returns (uint256);

    function _distribute(address sender, uint256 lenderAmount, Agreement calldata agreement) internal virtual;

    function _getCloseAmount(bytes calldata parameters) internal view virtual returns (uint256);

    // SECURITY Hello auditors. This feels risky.
    function transferContract(address controller) external override proxyExecution onlyRole(C.ADMIN_ROLE) {
        grantRole(C.ADMIN_ROLE, controller);
        renounceRole(C.ADMIN_ROLE, msg.sender);

        emit ControlTransferred(msg.sender, controller);
    }

    function passThrough(
        address payable destination,
        bytes calldata data,
        bool delegateCall
    ) external payable proxyExecution onlyRole(C.ADMIN_ROLE) returns (bool, bytes memory) {
        if (!delegateCall) {
            return destination.call{value: msg.value}(data);
        } else {
            return destination.delegatecall(data);
        }
    }
}
