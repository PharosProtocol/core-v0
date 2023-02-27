// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {Factory} from "src/modules/Factory.sol";

/**
 * Assessors are implemented using the Minimal Proxy Contract standard (https://eips.ethereum.org/EIPS/eip-1167).
 * Each unique Implementation Contract represents one computation method for assessing cost of a loan.
 * Each clone represents different set of call arguments to the assessing Method.
 * Each Implementation Contract must implement the functionionality of the standard Assessor Interface defined here.
 * Implementations may also offer additional non-essential functionality beyond the standard interface.
 */

/*
 * Each Assessor clone is used to determine the cost of a loan.
 */
interface IAssessor {
    function getCost(address position) external view returns (uint256);

    // Comparison operators are used so that Offers/Request can define a range of Assessors.
    function getCreationArguments() external view returns (bytes memory);
    function isGTE(bytes calldata altArguments) external view returns (bool);
    function isLTE(bytes calldata altArguments) external view returns (bool);
}

abstract contract AssessorFactory is IAssessor, Factory {
    bytes internal creationArguments;

    // Initialization logic used in all clones of all Assessors.
    function initialize(bytes calldata arguments) external override initializer {
        creationArguments = arguments;
        setArguments();
    }

    function setArguments() internal virtual;

    function getCreationArguments() external view override returns (bytes memory) {
        return creationArguments;
    }
}
