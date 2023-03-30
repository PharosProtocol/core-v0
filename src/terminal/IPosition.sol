// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import "src/protocol/C.sol";

/*
 * Each Position represents one deployment of capital through a Terminal.
 * Position status is determined by address assignment to CONTROLLER_ROLE.
 */
interface IPosition is IAccessControl {
    /// @notice Get current value of the position, denoted in base currency (USDC).
    function getValue(bytes calldata parameters) external view returns (uint256);
    /// @notice Fully exit the position in the same asset it was entered with. Assets remain in contract.
    function exit(bytes calldata parameters) external returns (uint256); // onlyRole(CONTROLLER_ROLE)
    /// @notice Transfer the position to a new controller. Used for liquidations.
    /// @dev do not set admin role to prevent liquidator from pushing the position back into the protocol.
    function transferContract(address controller) external; // onlyRole(CONTROLLER_ROLE)
    /// @notice Pass through function to allow the position to interact with other contracts after liquidation.
    function passThrough(address payable destination, bytes calldata data)
        external
        payable
        returns (bool, bytes memory); // onlyRole(CONTROLLER_ROLE)
}

abstract contract Position is AccessControl, IPosition {
    event ControlTransferred(address indexed previousController, address indexed newController);

    function transferContract(address controller) external override onlyRole(C.CONTROLLER_ROLE) {
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

    function exit(bytes calldata parameters) external override onlyRole(C.CONTROLLER_ROLE) returns (uint256 amount) {
        amount = _exit(parameters);
        renounceRole(C.CONTROLLER_ROLE, address(this));
        // renounceRole(DEFAULT_ADMIN_ROLE); // this isn't necessary as the immutable contract provably cannot abuse this. No trust needed.
    }

    function _exit(bytes calldata parameters) internal virtual returns (uint256);

    function passThrough(address payable destination, bytes calldata data)
        external
        payable
        onlyRole(C.CONTROLLER_ROLE)
        returns (bool, bytes memory)
    {
        return destination.call{value: msg.value}(data);
    }
}
