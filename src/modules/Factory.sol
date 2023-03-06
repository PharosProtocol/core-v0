// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import "src/protocol/C.sol";

import {Clones} from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/**
 * External Modules (Terminals, Oracles, Assessors, Liquidatiors?, etc) are implemented using the Minimal Proxy
 * Contract standard (https://eips.ethereum.org/EIPS/eip-1167).
 * Each unique Implementation Contract represents one computation method for one type of Module.
 * Each clone represents different set of call parameters or capital utilized by the the computation Method.
 * Parameters are stored in proxy contract state and set by the initializer.
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

interface IFactory {
    function createClone(bytes calldata parameters) external returns (address addr);
}

interface IClone {
    function initialize(bytes calldata parameters) external;
}

/*
 * The Factory is used to spawn clones and call their initializer to set instance-specific parameters.
 */
abstract contract Factory is Initializable, IClone, IFactory {
    event CloneCreated(address clone, bytes parameters);

    bool internal isFactory;
    mapping(address => bool) internal clones; // only some types of factories use this, can bubble up to save gas?

    constructor() {
        // Do not allow initialization in implementation contract.
        _disableInitializers();
        isFactory = true;
    }

    /// Functions defined below will use state of clones.

    /*
     * Must be called on all proxy clones immediately after creation.
     * NOTE "When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure that all initializers are idempotent" <- idk what this is about, but sounds relevant.
     */
    function initialize(bytes calldata parameters) external virtual; // use *initializer* modifier

    /*
     * Create clone of this implementation contract, set protocol role, and initialize it by setting parameters
     * in clone state.
     */
    function createClone(bytes calldata parameters) external returns (address addr) {
        require(isFactory);
        addr = Clones.clone(address(this));
        IClone clone = IClone(addr); // does MPC guarantee unique addresses for clones?
        clone.initialize(parameters);
        clones[addr] = true;
        emit CloneCreated(addr, parameters); // Emitted from Implementation Contract address.
    }
}

/*
 * Two clones derived from the same ParameterFactory can be quantitatively compared to each other,
 * which enables Offers to define ranges.
 */
interface IComparableParameterFactory is IFactory {
    function isGT(address clone0, address clone1) external view returns (bool);
    function isLT(address clone0, address clone1) external view returns (bool);
    // function isFactoryOf(address clone) external view returns (bool);
    // function getCreationParameters() external view returns (bytes memory);
}

abstract contract ComparableParameterFactory is IComparableParameterFactory, Factory {
    function isGT(address clone0, address clone1) external view returns (bool) {
        // requires(isFactory); // redundant with below
        require(clones[clone0] && clones[clone1]); // this assumes state variable state is not copied to clones at creation time.
        return _isGT(clone0, clone1);
    }

    function _isGT(address clone0, address clone1) internal view virtual returns (bool);

    function isLT(address clone0, address clone1) external view returns (bool) {
        // requires(isFactory); // redundant with below
        require(clones[clone0] && clones[clone1]); // this assumes state variable state is not copied to clones at creation time.
        return _isLT(clone0, clone1);
    }

    function _isLT(address clone0, address clone1) internal view virtual returns (bool);
}
