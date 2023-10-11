// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {Oracle} from "../Oracle.sol";
import "@chainlink/AggregatorV2V3Interface.sol";


contract ChainlinkOracle is Oracle {

struct Parameters {
        address addr; //chainlink price feed address .
    }

    function getOpenPrice(bytes calldata parameters, bytes calldata fillerData) external view returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        return _value(params.addr);
    }

    function getClosePrice(bytes calldata parameters, bytes calldata fillerData) external view returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        return _value(params.addr);
    }

     function _value(address addr) private view returns (uint) {
    (, int256 answer, , ,) = AggregatorV3Interface(addr).latestRoundData();
    uint256 value;
    uint80 decimals;
    decimals = AggregatorV3Interface(addr).decimals();
    value = uint256(answer) * C.RATIO_FACTOR / (10**uint256(decimals)); // adjusted for 18 dec precision
    return value;
}

}