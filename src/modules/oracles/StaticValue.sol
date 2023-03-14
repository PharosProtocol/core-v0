// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {IOracle} from "src/modules/oracles/IOracle.sol";

// NOTE yes, this would be cheaper by allowing an int to be set directly for the position, but is this really such an
//      important use case that the entire design should be altered? i don't think so.

interface IStaticPriceOracle is IOracle {
    function decodeParameters(bytes calldata parameters) external pure returns (uint256 value);
}

/*
 * This is a contract that represents one method of computing asset prices.
 * Its computation will differ for each set of parameters provided.
 * Modulus will interact directly with the clone using only the standard functions.
 */
contract StaticPriceOracle is IStaticPriceOracle {
    function decodeParameters(bytes calldata parameters) public pure returns (uint256) {
        return abi.decode(parameters, (uint256));
    }

    /// @dev no illegal parameters within the type constraints.
    function verifyParameters(bytes calldata) external pure override {
        return;
    }

    /// @dev ignore amount parameter
    function getValue(uint256 amount, bytes calldata parameters) external pure returns (uint256) {
        return amount * decodeParameters(parameters); // rounding?
    }

    function getAmount(uint256 value, bytes calldata parameters) external pure returns (uint256) {
        return value * decodeParameters(parameters); // rounding?
    }
}
