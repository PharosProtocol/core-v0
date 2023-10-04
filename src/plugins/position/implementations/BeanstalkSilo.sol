// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAccount} from "src/interfaces/IAccount.sol";
import {C} from "src/libraries/C.sol";
import {Position} from "src/plugins/position/Position.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {IWell} from "lib/Beanstalk/IWell.sol";
import "lib/Beanstalk/LibTransfer.sol";


/*
 * Swaps WETH to Bean:ETH well LP tokens and deposits in Beanstalk Silo.
 */

interface ISilo {
    function deposit(
        address token,
        uint256 _amount,
        LibTransfer.From mode
    )
        external
        payable
        returns (uint256 amount, uint256 _bdv, int96 stem);
}

contract BeanstalkSiloFactory is Position {
    struct Parameters {
        uint256 beanAsset;
    }

    constructor(address protocolAddr) Position(protocolAddr) {}
   
    /// @dev assumes assets are already in Position.
    function _open(Agreement calldata agreement) internal override {
        
        address beanEthWell = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd;
        address beanstalkAddr = 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5;
        
        //approve Bean:ETH well to use WETH
        IERC20 token = IERC20(C.WETH);
        token.approve(beanEthWell, 2e18);
        uint256[] memory tokenAmountsIn = new uint256[](2);
        tokenAmountsIn[0] = 0;
        tokenAmountsIn[1] = 2e11; 
        
        uint lpAmountOut = IWell(beanEthWell).addLiquidity(
            tokenAmountsIn,
            0,
            agreement.position.addr,
            block.timestamp * 2
        );

        // approve Silo to use Bean:ETH well LP tokens
        IERC20 lptoken = IERC20(beanEthWell);
        lptoken.approve(beanstalkAddr, 2e18);

        // deposit Bean:ETH LP tokens in Silo
        ISilo(beanstalkAddr).deposit(beanEthWell,lpAmountOut,LibTransfer.From.EXTERNAL);



    }

    function _close(Agreement calldata agreement, uint256 amountToClose) internal override {

 }

    // Public Helpers.

    function _getCloseAmount(Agreement calldata agreement) internal view override returns (uint256) {
        uint256 value = (agreement.collAmount *
            IOracle(agreement.collOracle.addr).getOpenPrice(agreement.collOracle.parameters)) / C.RATIO_FACTOR;
        return value;
    }
}
