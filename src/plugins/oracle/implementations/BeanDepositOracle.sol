// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {Oracle} from "src/plugins/oracle/Oracle.sol";
import {IWell} from "lib/Beanstalk/IWell.sol";
import {IInstantaneousPump} from "lib/Beanstalk/IInstantaneousPump.sol";
import "@chainlink/AggregatorV2V3Interface.sol";

interface IBeanstalk {
    function wellBdv(address token, uint256 amount) external view returns (uint256);
    function curveToBDV(uint256 amount) external view returns (uint256);
    function getDepositId( address token, int96 stem ) external pure returns (uint256);
    function balanceOf( address account, uint256 depositId ) external view returns (uint256 amount);
    function getDeposit(address account, address token,int96 stem) external view returns (uint256, uint256); 
}

contract BeanDepositOracle is Oracle {
    address BEANSTALK_PUMP = 0xBA510f10E3095B83a0F33aa9ad2544E22570a87C;
    address BEAN_ETH_WELL = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd;
    address BEANSTALK = 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5;

    mapping(uint256 => uint256) public tokenIdAmount;

    struct Parameters{
        uint256 tokenId;
        address account;
    }

    function getOpenPrice(bytes calldata parameters, bytes calldata fillerData) external  returns (uint256) {
        return _value(parameters,fillerData);
    }

    function getClosePrice(bytes calldata parameters, bytes calldata fillerData) external  returns (uint256) {
        return _value(parameters,fillerData);
    }

    function _getAmount(uint256 tokenId, address token, int96 stem, address account) internal  returns (uint256){

        uint256 depositId = IBeanstalk(BEANSTALK).getDepositId(token, stem);
        uint256 amount = IBeanstalk(BEANSTALK).balanceOf(account, depositId);
        
        // Save the amount into the mapping
        tokenIdAmount[tokenId] = amount;
    }

    function _value(bytes calldata parameters, bytes calldata fillerData) internal  returns (uint256) {
        uint256 value;
        bytes memory effectiveParameters = parameters;
        if (parameters.length == 0) {
            effectiveParameters = fillerData;
        }
        (uint256 tokenId, address account) = abi.decode(effectiveParameters, (uint256, address));
        (address token, int96 stem) = (address(uint160(tokenId >> 96)), int96(int256(tokenId)));

        if (tokenIdAmount[tokenId] == 0) {_getAmount(tokenId,token,stem,account);}
        uint256 amount=tokenIdAmount[tokenId] ;
       

        //get ETH:BEAN price from BEANSTALK_PUMP = 0xBA510f10E3095B83a0F33aa9ad2544E22570a87C , BEAN:ETH_WELL = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd
        uint[] memory reserves = IInstantaneousPump(BEANSTALK_PUMP).readInstantaneousReserves(
            BEAN_ETH_WELL,
            C.BYTES_ZERO
        );
        uint256 ethBeanvalue;
        uint256 beanUsdValue;
        ethBeanvalue = ((reserves[0] * (1e30)) / reserves[1]); //price of ETH in Beans 18 dec precision

        //Get ETH:USD price from Chainlink DataFeed 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        (, int256 answer, , , ) = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419).latestRoundData();
        uint256 ethUsdValue;
        ethUsdValue = (uint256(answer) * C.RATIO_FACTOR) / (10 ** (8)); // price of ETH in USD in 18 dec precision
        beanUsdValue = (ethUsdValue * C.RATIO_FACTOR) / ethBeanvalue; // price of Bean in USD in 18 dec precision
        if (token == 0xBEA0000029AD1c77D3d5D23Ba2D8893dB9d1Efab) {
            // return BEAN:USD (number of USD per Bean) price with 18 dec precision
            value= beanUsdValue*amount/10**(6);

        } else if (token == 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd) {
            // return BeanEthLP:USD (number of USD per Bean:ETH LP) price with 18 dec precision
            uint256 wellBDV = IBeanstalk(BEANSTALK).wellBdv(BEAN_ETH_WELL, 1e18);
            value= ((beanUsdValue * wellBDV*amount)/(10**(6)*C.RATIO_FACTOR));


        } else if (token == 0xc9C32cd16Bf7eFB85Ff14e0c8603cc90F6F2eE49 ) 
        {   // return 3CRV:USD (number of USD per 3CRV) price with 18 dec precision
            uint256 crvBDV = IBeanstalk(BEANSTALK).curveToBDV(1e18);
            value= ((beanUsdValue * crvBDV*amount)/(10**(6)*C.RATIO_FACTOR));
        }
        return value;
    }
}
