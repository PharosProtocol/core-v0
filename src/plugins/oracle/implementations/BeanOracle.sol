// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {Oracle} from "src/plugins/oracle/Oracle.sol";
import {IWell} from "lib/Beanstalk/IWell.sol";
import {IInstantaneousPump} from "lib/Beanstalk/IInstantaneousPump.sol";
import "@chainlink/AggregatorV2V3Interface.sol";

interface ISilo {
    function wellBdv(address token, uint256 amount) external view returns (uint256);
    function curveToBDV(uint256 amount) external view returns (uint256);
}


contract BeanOracle is Oracle {
    address BEANSTALK_PUMP = 0xBA510f10E3095B83a0F33aa9ad2544E22570a87C;
    address BEAN_ETH_WELL = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd;
    address BEANSTALK = 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5;


struct Parameters {
        uint8 input; //1 for Bean, 2 for Bean:ETH and 3 for Bean:3CRV
    }
    

    function getOpenPrice(bytes calldata parameters) external view returns (uint256) {
        return _value(parameters);
    }

    function getClosePrice(bytes calldata parameters) external view returns (uint256) {
        return _value(parameters);
    }

    function _value(bytes calldata parameters) internal view returns (uint256) {
        
        uint8 input = abi.decode(parameters, (uint8));

        //get ETH:BEAN price from BEANSTALK_PUMP = 0xBA510f10E3095B83a0F33aa9ad2544E22570a87C , BEAN:ETH_WELL = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd
        uint[] memory reserves = IInstantaneousPump(BEANSTALK_PUMP).readInstantaneousReserves(BEAN_ETH_WELL, C.BYTES_ZERO);
        uint256 ethBeanvalue;
        uint256 beanUsdValue;
        ethBeanvalue= ((reserves[0] * (1e30)) / reserves[1]); //price of ETH in Beans 18 dec precision
        
        //Get ETH:USD price from Chainlink DataFeed 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        (, int256 answer, , ,) = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419).latestRoundData();
        uint256 ethUsdValue;
        ethUsdValue = uint256(answer) * C.RATIO_FACTOR / (10**uint256(8)); // adjusted for 18 dec precision
        beanUsdValue = ethBeanvalue*C.RATIO_FACTOR/ethUsdValue;
        if (input ==1){

        // return USD:BEAN (number of Beans per USD) price with 18 dec precision 
            return 1/beanUsdValue;
        }
        else if (input == 2){
        // return USD:BeanEthLP (number of Bean:ETH LP per USD) price with 18 dec precision 
        uint256 wellBDV =  ISilo(BEANSTALK).wellBdv(BEAN_ETH_WELL,1);

        return 1/(beanUsdValue*wellBDV);
        }
        else if (input == 3)
        // return USD:3CRV (number of 3CRV per USD) price with 18 dec precision 

         {
            uint256 crvBDV =  ISilo(BEANSTALK).curveToBDV(1);

            
            return 1/(beanUsdValue*crvBDV);}
        
    }

    }
    
