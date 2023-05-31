// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {C} from "src/C.sol";

import {Asset} from "src/LibUtil.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Agreement} from "src/bookkeeper/Bookkeeper.sol";
import {Clones} from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/// NOTE: Should define parameter invariants to confirm that clone parameters are valid before showing in UI.

/**
 * Factories are implemented using the Minimal Proxy Contract standard (https://eips.ethereum.org/EIPS/eip-1167).
 * Each implementation contract (Factory) represents one interface to an external protocol.
 * Each clone represents one Position in the Factory.
 * Each implementation contract must implement the functionality of the standard Factory Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 *
 * This will enable several key features:
 * 1. Permissionlessness. Any user can deploy arbitrarily complex logic used to define an agreement.
 * 2. Deep separation of positions. User deployed assets are not co-mingled.
 * 3. Ability for logical modules to have arbitrarily nuanced interfaces, as long as they support the
 *    minimal set of features in the standard interface.
 */

/*
 * The Factory is used to spawn positions (clones) and call their intializers.
 */

abstract contract PositionFactory is AccessControl, Initializable {
    address public immutable BOOKKEEPER_ADDRESS; // Modulus address
    address public immutable FACTORY_ADDRESS; // Implementation contract address // assumes proxy constant values are set by implementation contract

    // Metadata metadata;

    event PositionCreated(address position);

    modifier implementationExecution() {
        require(address(this) == FACTORY_ADDRESS);
        _;
    }

    modifier proxyExecution() {
        require(address(this) != FACTORY_ADDRESS);
        _;
    }

    /// @dev constructor only called in implementation contract, not clones
    constructor(address bookkeeperAddr) {
        // Do not allow initialization in implementation contract.
        _disableInitializers(); // redundant with proxyExecution modifier?
        BOOKKEEPER_ADDRESS = bookkeeperAddr;
        FACTORY_ADDRESS = address(this);
        _setupRole(C.ADMIN_ROLE, BOOKKEEPER_ADDRESS); // Factory role set
    }

    /*
     * Create position (clone) that will use this Factory.
     */
    function createPosition() external implementationExecution onlyRole(C.ADMIN_ROLE) returns (address addr) {
        addr = Clones.clone(address(this));
        (bool success,) = addr.call(abi.encodeWithSignature("initialize()"));
        require(success, "createPosition: initialize fail");
        emit PositionCreated(addr);
    }

    /*
     * Must be called on all proxy clones immediately after creation.
     * NOTE "When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure that all initializers are idempotent" <- idk what this is about, but sounds relevant.
     * NOTE cannot do role check modifier here because state not yet set
     */
    function initialize() external initializer proxyExecution {
        require(msg.sender == FACTORY_ADDRESS);
        _setupRole(C.ADMIN_ROLE, BOOKKEEPER_ADDRESS); // Position role set
    }

    receive() external payable {}
}
