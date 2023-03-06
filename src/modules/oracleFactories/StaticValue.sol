// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {Factory} from "src/modules/Factory.sol";
import {IOracle} from "src/modules/OracleFactory.sol";

/*
 * This is an implementation contract that represents one method of computing asset prices.
 * It will create a clone for each unique set of parameters used (path, slippage).
 * Modulus will interact directly with the clone using only the standard functions.
 */
contract StaticPriceOracle is IOracle, Factory {
    // Static value to assign each NFT.
    uint256 private value;

    function initialize(bytes calldata parameters) external override initializer {
        (value) = abi.decode(parameters, (uint256));
    }

    function getValue(uint256 amount) external view override returns (uint256) {
        return amount * value;
    }
}
