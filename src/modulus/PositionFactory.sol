// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "src/modulus/C.sol";

import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Clones} from "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

/*
 * Terminals could/should be implemented as Minimal Contract Implementations, where a single terminal
 * contract is a wrapper over a protocol the basically represents a whitelist of allowed actions
 * for a user to take against that protocol. MCIs can then be spun up for each Position created
 * through modulend and represents a single position (one user, one loan). The user can then directly
 * perform supplementary actions with their position (Farm, swap asset, etc), although interactions
 * like transferring assets or closing the position will still need to be performed through Modulend
 * via the strictly defined functions shown below.
 * This will enable several key features:
 * 1. Modularity of positions. User depoloyed assets are not comingled.
 * 2. Ability for terminals to have arbitrarily nuanced interfaces, as long as they support the
 *    minimal set of features in the standard interface.
 *
 * A terminal represents a gateway to deploy capital in a specific positon. Every terminal,
 * regargless of attached protocol or positon, must implement this interface. Term Sheets are able to interact
 * with terminals using this interface without any knowledge of the underlying implementation.
 *
 * The asset that the position was entered with must be used for valuation and exiting.
 */
interface IPositionFactory {
    function initialize(address borrower) external; // onlyRole(PROTOCOL_ROLE)
    function createPosition(address borrower) external returns (address addr);
}

/// How do we ensure third party Terminals meet our standards? Likely need to audit each to get a certification, but
/// there should be a lower bar to enable permissionlessness. Seems like Solidity does not have the inheritance
/// controls necessary to guarantee they are using a minimum set of code and modifiers.
/// Perhaps could write a standard test suite + environment and require it to pass before listing on website?
/// Require contract code to be verified on etherscan?

/*
 * This contract is used to create Minimal Proxy Contracts that connect to an already deployed Terminal.
 */
abstract contract PositionFactory is AccessControl, Initializable, IPositionFactory {
    bytes32 internal constant BORROWER_ROLE = keccak256("BORROWER_ROLE");
    bytes32 internal constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");
    address public constant PROTOCOL_ADDRESS = C.MODULEND_ADDR; // Modulus address

    event PositionCreated(address position);

    constructor() {
        // Do not allow initialization in implementation contract.
        _disableInitializers();
    }

    /// Functions defined below will always be the same, in all terminals. They will use state of clones.

    /*
     * Will be called on all proxy clones immediately after creation.
     * "When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure that all initializers are idempotent" <- idk what this is about, but sounds relevant.
     */
    function initialize(address borrower) external initializer {
        _grantRole(PROTOCOL_ROLE, PROTOCOL_ADDRESS);
        _grantRole(BORROWER_ROLE, borrower);
    }

    /*
     * Create Minimum Proxy Implementation for this implementation contract.
     */
    function createPosition(address borrower) external onlyRole(PROTOCOL_ROLE) returns (address addr) {
        addr = Clones.clone(address(this));
        IPositionFactory(addr).initialize(borrower);
        emit PositionCreated(addr);
    }
}
