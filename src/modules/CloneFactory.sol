// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "src/protocol/C.sol";

import {Clones} from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/**
 * External Modules (Terminals, Oracles, Assessors, Liquidatiors?, etc) are implemented using the Minimal Proxy
 * Contract standard (https://eips.ethereum.org/EIPS/eip-1167).
 * Each unique Implementation Contract represents one computation method for one type of Module.
 * Each clone represents different set of call arguments or capital utilized by the the computation Method.
 * Arguments are stored in proxy contract state and set by the initializer.
 * Each Implementation Contract must implement the functionionality of the standard interface for that Module Type.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 *
 * This will enable several key features:
 * 1. Permissionlessness. Any user can deploy arbitrarily complex logic used to define an agreement.
 * 2. Programatic detection and comprehension of argument sets (clones).
 * 3. Deep seperation of positions. User depoloyed assets are not comingled.
 * 3. Ability for logical modules to have arbitrarily nuanced interfaces, as long as they support the
 *    minimal set of features in the standard interface.
 */

interface ICloneFactory {
    function initialize(bytes calldata arguments) external;
}

/*
 * The CloneFactory is used to spawn clones and call their initializer to set instance-specific arguments.
 */
abstract contract CloneFactory is Initializable, ICloneFactory {
    event CloneCreated(address clone, bytes arguments);

    constructor() {
        // Do not allow initialization in implementation contract.
        _disableInitializers();
    }

    /// Functions defined below will use state of clones.

    /*
     * Must be called on all proxy clones immediately after creation.
     * NOTE "When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure that all initializers are idempotent" <- idk what this is about, but sounds relevant.
     */
    function initialize(bytes calldata arguments) external virtual initializer {} // NOTE calling initializer here does nothing, requires nothing?

    /*
     * Create clone of this implementation contract, set protocol role, and initialize it by setting arguments
     * in clone state.
     */
    function createClone(bytes calldata arguments) internal returns (address addr) {
        addr = Clones.clone(address(this));
        ICloneFactory cloneFactory = ICloneFactory(addr);
        cloneFactory.initialize(arguments);
        emit CloneCreated(addr, arguments); // Emitted from Implementation Contract address.
    }
}
