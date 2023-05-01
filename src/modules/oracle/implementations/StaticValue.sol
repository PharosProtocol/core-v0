// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {IOracle} from "../IOracle.sol";
import {Asset} from "src/LibUtil.sol";

/*
 * This is a contract that represents one method of computing asset prices.
 * Its computation will differ for each set of parameters provided.
 * Modulus will interact directly with the clone using only the standard functions.
 */
contract StaticPriceOracle is IOracle {
    struct Parameters {
        address asset;
        uint256 value;
    }

    /// @dev no illegal parameters possible within the type constraints.
    function verifyParameters(Asset calldata, bytes calldata) external pure override {
        return;
    }

    /// @dev ignore amount parameter
    function getValue(Asset calldata asset, uint256 amount, bytes calldata parameters) external pure returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        require(asset.addr == params.asset);
        return amount * params.value; // rounding?
    }

    function getAmount(Asset calldata asset, uint256 value, bytes calldata parameters) external pure returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        require(asset.addr == params.asset);
        return value / params.value; // rounding?
    }
}
