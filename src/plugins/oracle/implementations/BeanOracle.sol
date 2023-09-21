// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {Oracle} from "../Oracle.sol";

interface BeanPriceInterface {
    struct Prices {
        uint256 price;
        uint256 liquidity;
        int deltaB;
    }

    function price() external view returns (Prices memory p);
}

contract BeanOracle is Oracle {



    function getOpenPrice(bytes calldata parameters) external view returns (uint256) {
        
        return _value();
    }

    function getClosePrice(bytes calldata parameters) external view returns (uint256) {
        return _value();
    }

    address public beanPriceContract = 0xb01CE0008CaD90104651d6A84b6B11e182a9B62A;

    function _value() public view returns (uint256) {
    BeanPriceInterface targetContract = BeanPriceInterface(beanPriceContract);
    BeanPriceInterface.Prices memory prices = targetContract.price();
    return prices.price;
}


}

