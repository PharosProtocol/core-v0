// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {Oracle} from "src/plugins/oracle/Oracle.sol";
import {IWell} from "./IWell.sol";
import {IInstantaneousPump} from "./IInstantaneousPump.sol";


contract BeanOracle is Oracle {
    function getOpenPrice(bytes calldata parameters) external view returns (uint256) {
        return _value();
    }

    function getClosePrice(bytes calldata parameters) external view returns (uint256) {
        return _value();
    }

    address public beanPriceContract = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd;

    function _value() internal view returns (uint256) {
        uint[] memory reserves = IInstantaneousPump(0xBA510f10E3095B83a0F33aa9ad2544E22570a87C).readInstantaneousReserves(0xBEA0e11282e2bB5893bEcE110cF199501e872bAd, C.BYTES_ZERO);
        return ((reserves[0] * (1e18)) / reserves[1]);
    }

    }
    
