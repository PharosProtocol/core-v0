// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import "src/protocol/C.sol";
import {Factory} from "src/modules/Factory.sol";
import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

/// Should their be a second layer of MPC for terminals? One layer for parameters and one layer for positions.

struct InitState {
    address asset;
    uint256 amount;
    uint256 time;
}

/*
 * Terminals are implemented using the Minimal Proxy Contract standard (https://eips.ethereum.org/EIPS/eip-1167).
 * Each unique Implementation Contract represents one method of deployement.
 * Each clone represents a position representing some capital using the deployment method.
 * Each Implementation Contrat must implements the functionality of the standard Terminal Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 */

/*
 * Each Terminal clone is used to manage one position.
 */
interface IPosition {
    function exit(bytes calldata data) external returns (uint256);
    function getValue() external view returns (uint256);
    function getInitState() external view returns (address, uint256, uint256);
}

abstract contract PositionFactory is IPosition, AccessControl, Factory {
    bytes32 internal constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");
    address public constant PROTOCOL_ADDRESS = C.MODULEND_ADDR; // Modulus address

    InitState internal initState;

    function initialize(bytes calldata parameters) external override {
        _grantRole(PROTOCOL_ROLE, PROTOCOL_ADDRESS);
        enter(parameters);
    }

    function enter(bytes calldata parameters) internal virtual;

    function getInitState() external view override returns (address, uint256, uint256) {
        return (initState.asset, initState.amount, initState.time);
    }
}
