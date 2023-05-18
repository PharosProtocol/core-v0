// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Oracle} from "../Oracle.sol";
import {Asset} from "src/LibUtil.sol";

/*
 * This is a contract that represents one method of computing asset prices.
 * Its computation will differ for each set of parameters provided.
 * Modulus will interact directly with the clone using only the standard functions.
 */
contract StaticUsdcPriceOracle is Oracle {
    struct Parameters {
        uint256 value; // decimals = 6
    }

    /// @dev no illegal parameters possible within the type constraints.
    function verifyParameters(Asset calldata, bytes calldata) external pure override {
        return;
    }

    /// @dev ignore amount parameter
    function getValue(Asset calldata, uint256 amount, bytes calldata parameters)
        external
        pure
        returns (uint256)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));
        // require(asset.addr == params.valueAsset);
        return amount * params.value; // rounding?
    }

    function getAmount(Asset calldata, uint256 value, bytes calldata parameters)
        external
        pure
        returns (uint256)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));
        // require(asset.addr == params.valueAsset, "StaticPriceOracle: asset mismatch");
        return value / params.value; // rounding?
    }
}
