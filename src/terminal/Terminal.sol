// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {C} from "src/C.sol";

import {Asset} from "src/LibUtil.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Agreement} from "src/bookkeeper/Bookkeeper.sol";
import {Clones} from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import {ITerminal} from "src/terminal/ITerminal.sol";
import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

import {Position} from "src/terminal/IPosition.sol";

/// NOTE: Should define parameter invariants to confirm that clone parameters are valid before showing in UI.

/**
 * Terminals are implemented using the Minimal Proxy Contract standard (https://eips.ethereum.org/EIPS/eip-1167).
 * Each implementation contract (Terminal) represents one interface to an external protocol.
 * Each clone represents one Position in the Terminal.
 * Each implementation contract must implement the functionality of the standard Terminal Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 *
 * This will enable several key features:
 * 1. Permissionlessness. Any user can deploy arbitrarily complex logic used to define an agreement.
 * 2. Deep separation of positions. User deployed assets are not co-mingled.
 * 3. Ability for logical modules to have arbitrarily nuanced interfaces, as long as they support the
 *    minimal set of features in the standard interface.
 */

/// @dev not expected to be used outside of this file.
interface IChildClone {
    function initialize() external;
}

/*
 * The Terminal is used to spawn positions (clones) and call their intializers.
 */

abstract contract Terminal is ITerminal, IChildClone, Position, Initializable {
    address public immutable BOOKKEEPER_ADDRESS; // Modulus address
    address public immutable TERMINAL_ADDRESS; // Implementation contract address // assumes proxy constant values are set by implementation contract

    // Metadata metadata;

    event PositionCreated(address indexed position);
    event PositionClosed(bytes parameters);

    modifier implementationExecution() {
        require(address(this) == TERMINAL_ADDRESS);
        _;
    }

    modifier proxyExecution() {
        require(address(this) != TERMINAL_ADDRESS);
        _;
    }

    /// @dev constructor only called in implementation contract, not clones
    constructor(address bookkeeperAddr) {
        // Do not allow initialization in implementation contract.
        _disableInitializers(); // redundant with proxyExecution modifier?
        BOOKKEEPER_ADDRESS = bookkeeperAddr;
        TERMINAL_ADDRESS = address(this);
        _grantRole(C.BOOKKEEPER_ROLE, BOOKKEEPER_ADDRESS); // Terminal role set
    }

    /*
     * Create position (clone) that will use this terminal.
     */
    function createPosition()
        external
        override
        implementationExecution
        onlyRole(C.BOOKKEEPER_ROLE)
        returns (address addr)
    {
        addr = Clones.clone(address(this));
        IChildClone(addr).initialize();
        // addr.call(abi.encodeWithSignature("initialize(bytes)", parameters));
        emit PositionCreated(addr);
    }

    /*
     * Must be called on all proxy clones immediately after creation.
     * NOTE "When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure that all initializers are idempotent" <- idk what this is about, but sounds relevant.
     * NOTE cannot do role check modifier here because state not yet set
     */
    function initialize() external override initializer proxyExecution {
        require(msg.sender == TERMINAL_ADDRESS);
        _grantRole(C.BOOKKEEPER_ROLE, BOOKKEEPER_ADDRESS); // Position role set
    }

    receive() external payable {}

    // function _exit(bytes calldata parameters) internal virtual returns (uint256 exitAmount) internal virtual;
}
