// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {Oracle} from "../Oracle.sol";
import "@chainlink/AggregatorV2V3Interface.sol";


contract ChainlinkOracle is Oracle {

struct Parameters {
        address addr; //with 18 decimal places precision.
    }

    function getOpenPrice(bytes calldata parameters) external view returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        return _value(params.addr);
    }

    function getClosePrice(bytes calldata parameters) external view returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        return _value(params.addr);
    }

     function _value(address addr) private view returns (uint) {
    (, int256 answer, , , uint80 decimals) = AggregatorV3Interface(addr).latestRoundData();
    uint256 value;
    value = uint256(answer) * C.RATIO_FACTOR / (10**uint256(decimals)); // adjusted for 18 dec precision
    return value;
}

}