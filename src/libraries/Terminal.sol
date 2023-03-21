// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import "src/protocol/C.sol";

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Clones} from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import {ITerminal} from "src/interfaces/ITerminal.sol";
import {TerminalCalldata} from "src/libraries/LibTerminal.sol";
import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

import {IPosition} from "src/interfaces/IPosition.sol";

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
    function initialize(TerminalCalldata calldata terminalCalldata) external;
}

/*
 * The Terminal is used to spawn positions (clones) and call their intializers.
 */

abstract contract Terminal is ITerminal, IChildClone, IPosition, Initializable, AccessControl {
    bytes32 internal constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE"); // pretty sure constants set in impl contract will be the same for all clones
    address public constant PROTOCOL_ADDRESS = address(1); // Modulus address
    address public immutable TERMINAL_ADDRESS; // Implementation contract address // assumes proxy constant values are set by implementation contract

    // Metadata metadata;

    event PositionCreated(address terminal, address asset, uint256 amount, bytes parameters);
    event PositionClosed(bytes parameters);

    modifier implementationExecution() {
        require(address(this) == TERMINAL_ADDRESS);
        _;
    }

    modifier cloneExecution() {
        require(address(this) != TERMINAL_ADDRESS);
        _;
    }

    /// @dev constructor only called in implementation contract, not clones
    constructor() {
        // Do not allow initialization in implementation contract.
        _disableInitializers(); // redundant with cloneExecution modifier?
        TERMINAL_ADDRESS = address(this);
        _grantRole(PROTOCOL_ROLE, PROTOCOL_ADDRESS); // Terminal role set
    }

    /*
     * Create position (clone) that will use this terminal.
     */
    function createPosition(TerminalCalldata memory terminalCalldata)
        external
        implementationExecution
        onlyRole(PROTOCOL_ROLE)
        returns (address addr)
    {
        addr = Clones.clone(address(this));
        IChildClone clone = IChildClone(addr); // does MPC guarantee unique addresses for clones?
        clone.initialize(terminalCalldata);
        // addr.call(abi.encodeWithSignature("initialize(bytes)", parameters));
    }

    /*
     * Must be called on all proxy clones immediately after creation.
     * NOTE "When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure that all initializers are idempotent" <- idk what this is about, but sounds relevant.
     * NOTE cannot do role check modifier here because state not yet set
     */
    function initialize(TerminalCalldata calldata terminalCalldata) external override initializer cloneExecution {
        _grantRole(PROTOCOL_ROLE, PROTOCOL_ADDRESS); // Position role set

        _enter(terminalCalldata.asset, terminalCalldata.amount, terminalCalldata.parameters);
        emit PositionCreated(
            TERMINAL_ADDRESS, terminalCalldata.asset, terminalCalldata.amount, terminalCalldata.parameters
        );
    }

    function _enter(address asset, uint256 amount, bytes calldata parameters) internal virtual;

    function exit(bytes calldata parameters)
        external
        cloneExecution
        onlyRole(PROTOCOL_ROLE)
        returns (uint256 exitAmount)
    {
        exitAmount = _exit(parameters);
        emit PositionClosed(parameters);
    }

    function _exit(bytes calldata parameters) internal virtual returns (uint256 exitAmount);
}
