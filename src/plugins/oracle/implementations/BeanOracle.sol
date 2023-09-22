// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {Oracle} from "src/plugins/oracle/Oracle.sol";
import {IWell} from "lib/beanstalk/IWell.sol";
import {IInstantaneousPump} from "lib/beanstalk/IInstantaneousPump.sol";
import "@chainlink/AggregatorV2V3Interface.sol";



contract BeanOracle is Oracle {
    function getOpenPrice(bytes calldata parameters) external view returns (uint256) {
        return _value();
    }

    function getClosePrice(bytes calldata parameters) external view returns (uint256) {
        return _value();
    }

    address public beanPriceContract = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd;

    function _value() internal view returns (uint256) {
        //get ETH:BEAN price from BEANSTALK_PUMP = 0xBA510f10E3095B83a0F33aa9ad2544E22570a87C , BEAN:ETH_WELL = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd
        uint[] memory reserves = IInstantaneousPump(0xBA510f10E3095B83a0F33aa9ad2544E22570a87C).readInstantaneousReserves(0xBEA0e11282e2bB5893bEcE110cF199501e872bAd, C.BYTES_ZERO);
        uint256 ethBeanvalue;
        ethBeanvalue= ((reserves[0] * (1e30)) / reserves[1]); //price of ETH in Beans 18 dec precision
        

        //Get ETH:USD price from Chainlink DataFeed 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        (, int256 answer, , ,) = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419).latestRoundData();
        uint256 ethUsdValue;
        ethUsdValue = uint256(answer) * C.RATIO_FACTOR / (10**uint256(8)); // adjusted for 18 dec precision
        // return USD:BEAN (number of Beans per USD) price with 18 dec precision 
        return ethBeanvalue*C.RATIO_FACTOR/ethUsdValue;
    }

    }
    
