// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {CloneFactory} from "src/modulus/CloneFactory.sol";
import {Oracle} from "src/modulus/Oracle.sol";

/*
 * This is an implementation contract that represents one method of computing asset prices.
 * It will create a clone for each unique set of arguments used (path, slippage).
 * Modulus will interact directly with the clone using only the standard functions.
 */
contract StaticPriceOracle is Oracle {
    // Static value to assign each NFT.
    uint256 private value;

    function initializeArguments(bytes calldata arguments) internal override initializer {
        (value) = abi.decode(arguments, (uint256));
    }

    function getValue(uint256 amount) external override returns (uint256) {
        return amount * value;
    }
}
