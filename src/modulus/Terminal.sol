// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {PositionFactory} from "src/modulus/PositionFactory.sol";
import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

/*
 * Oracles are deployed in independent contracts. They should be stateless and match the interface specification
 * here.
 */
interface ITerminal {
    function createAndEnterPosition(address borrower, bytes calldata data) external;
    function exit(bytes calldata data) external returns (uint256);
    function getPositionValue(bytes calldata data) external returns (uint256);
}

abstract contract Terminal is AccessControl, ITerminal, PositionFactory {
    event TerminalCreated(address position);

    function createAndEnterPosition(address borrower, bytes calldata data) external onlyRole(PROTOCOL_ROLE) {
        createPosition(borrower);
        enter(data);
    }

    function enter(bytes calldata data) internal virtual;
}
