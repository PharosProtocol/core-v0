// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {Oracle} from "../Oracle.sol";
import {Asset} from "src/libraries/LibUtils.sol";

/*
 * This is a contract that represents one method of computing asset prices.
 * Its computation will differ for each set of parameters provided.
 * Modulus will interact directly with the clone using only the standard functions.
 */
contract StaticPriceOracle is Oracle {
    struct Parameters {
        uint256 ratio; // amount of token / 1e18 wei
    }

    function getResistantValue(uint256 amount, bytes calldata parameters) external pure returns (uint256) {
        return _value(amount, parameters);
    }

    function getSpotValue(uint256 amount, bytes calldata parameters) external pure returns (uint256) {
        return _value(amount, parameters);
    }

    function getResistantAmount(uint256 ethAmount, bytes calldata parameters) external pure returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        return ethAmount * params.ratio / (10 ** C.ETH_DECIMALS); // AUDIT rounding?
    }

    function canHandleAsset(Asset calldata, bytes calldata) external pure override returns (bool) {
        return true;
    }

    function _value(uint256 amount, bytes calldata parameters) private pure returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        return amount * (10 ** C.ETH_DECIMALS) / params.ratio; // AUDIT rounding?
    }
}
