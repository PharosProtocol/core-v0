// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {C} from "src/libraries/C.sol";

/**
 * Factories are implemented using the Minimal Proxy Contract standard (https://eips.ethereum.org/EIPS/eip-1167).
 * Each implementation contract (Factory) represents one interface to an external protocol.
 * Each clone represents one Position of a Terminal.
 * Each implementation contract must implement the functionality of the standard Factory Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 *
 * Primary use is expected to be in Positions, which must be implemented using MPCs.
 *
 * This will enable several key features:
 * 1. Permissionlessness. Any user can deploy arbitrarily complex logic used to define an agreement.
 * 2. Deep separation of positions. User deployed assets are not co-mingled.
 * 3. Ability for logical plugins to have arbitrarily nuanced interfaces, as long as they support the
 *    minimal set of features in the standard interface.
 */

abstract contract CloneFactory is AccessControl, Initializable {
    address public immutable BOOKKEEPER_ADDR;
    // SECURITY assumes proxy constant values are set by implementation contract
    address public immutable FACTORY_ADDR; // Implementation contract address

    event CloneCreated(address clone);

    modifier implementationExecution() {
        require(address(this) == FACTORY_ADDR, "exec not allowed in proxy");
        _;
    }

    modifier proxyExecution() {
        require(address(this) != FACTORY_ADDR, "exec not allowed in impl");
        _;
    }

    /// @dev constructor only called in implementation contract, not clones
    constructor(address bookkeeperAddr) {
        // Do not allow initialization in implementation contract.
        _disableInitializers(); // redundant with proxyExecution modifier?
        BOOKKEEPER_ADDR = bookkeeperAddr;
        FACTORY_ADDR = address(this);
        _setupRole(C.BOOKKEEPER_ROLE, BOOKKEEPER_ADDR); // Factory role set. Never changes.
    }

    /*
     * Create clone that will use this Factory.
     */
    function createClone() external payable implementationExecution onlyRole(C.BOOKKEEPER_ROLE) returns (address addr) {
        addr = Clones.clone(address(this));
        (bool success, ) = addr.call{value: msg.value}(abi.encodeWithSignature("initialize()"));
        require(success, "createClone: initialize fail");
        emit CloneCreated(addr);
    }

    /*
     * Must be called on all proxy clones immediately after creation.
     * Cannot do role check modifier here because state not yet set
     * NOTE "When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure that all initializers are idempotent" <- idk what this is about, but sounds relevant.
     */
    function initialize(bytes calldata initData) external payable initializer proxyExecution {
        require(msg.sender == FACTORY_ADDR, "sender != impl contract");
        _setupRole(C.CONTROLLER_ROLE, BOOKKEEPER_ADDR); // Clone role set. May change.
        _initialize(initData);
    }

    function _initialize(bytes calldata initData) internal virtual;

    receive() external payable {}
}
