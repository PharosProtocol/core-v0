// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {Oracle} from "../Oracle.sol";

/*
 * This is a contract that represents one method of computing asset prices.
 */
contract StaticOracle is Oracle {
    struct Parameters {
        uint256 number; //with 18 decimal places precision.
    }

    function getOpenPrice(bytes calldata parameters, bytes calldata fillerData) external pure returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        return params.number;
    }

    function getClosePrice(bytes calldata parameters, bytes calldata fillerData) external pure returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        return params.number;
    }
}

