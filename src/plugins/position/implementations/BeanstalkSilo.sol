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
import "@chainlink/AggregatorV2V3Interface.sol";


/*
 * Swaps WETH to Bean:ETH well LP tokens and deposits in Beanstalk Silo.
 */

interface ISilo {
    function deposit(
        address token,
        uint256 _amount,
        LibTransfer.From mode
    ) external payable returns (uint256 amount, uint256 _bdv, int96 stem);

    function plant() external payable returns (uint256 beans, int96 stem);

    function mow(address account, address token) external payable;

    function balanceOfEarnedBeans(address account) external view returns (uint256 beans);

    function wellBdv(address token, uint256 amount) external view returns (uint256);
    
    function withdrawDeposit(address token, int96 stem, uint256 amount, LibTransfer.To mode ) external payable;
}

contract BeanstalkSiloFactory is Position {

    uint256 lpDeposit;
    uint256 plantedBeans;
    int96 stem;
    bool unwound;

    struct Asset {
        uint8 standard; // asset type, 1 for ERC20, 2 for ERC721, 3 for ERC1155
        address addr; 
        uint8 decimals; //not used if ERC721
        uint256 tokenId; // for ERC721 and ERC1155
        bytes data;
    }
    struct Parameters {
        uint256 beanAsset;
    }
    struct OracleParameters {
        uint8 input; // used to get price - 1 for Bean, 2 for Bean:ETH and 3 for Bean:3CRV
    }

    constructor(address protocolAddr) Position(protocolAddr) {}

    /// @dev assumes assets are already in Position.
    function _open(Agreement calldata agreement) internal override {
    address BEAN_ETH_WELL = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd;
    address BEANSTALK = 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5;
    uint256 totalAmount = agreement.loanAmount + agreement.collAmount;
        //approve Bean:ETH well to use WETH
        IERC20 token = IERC20(C.WETH);
        token.approve(BEAN_ETH_WELL, totalAmount);
        uint256[] memory tokenAmountsIn = new uint256[](2);
        tokenAmountsIn[0] = 0;
        tokenAmountsIn[1] = totalAmount;

        uint lpAmountOut = IWell(BEAN_ETH_WELL).addLiquidity(
            tokenAmountsIn,
            0,
            agreement.position.addr,
            block.timestamp * 2
        );

        // approve Silo to use Bean:ETH well LP tokens
        IERC20 lptoken = IERC20(BEAN_ETH_WELL);
        lptoken.approve(BEANSTALK, lpAmountOut);

        // deposit Bean:ETH LP tokens in Silo
        (,,stem)= ISilo(BEANSTALK).deposit(BEAN_ETH_WELL, lpAmountOut, LibTransfer.From.EXTERNAL);
        lpDeposit = lpAmountOut;
    }

    function _close(Agreement calldata agreement, uint256 amountToLender) internal override {

        Asset memory loanAsset = abi.decode(agreement.loanAsset, (Asset));

        if (amountToLender > 0) {
            IERC20 loanToken = IERC20(loanAsset.addr);
            address lenderAccount = agreement.lenderAccount.addr;
            uint256 currentAllowance = loanToken.allowance(agreement.position.addr, lenderAccount);
    
            // If the current allowance is non-zero, reset it to zero
            if (currentAllowance > 0) {
            require(loanToken.approve(lenderAccount, 0), "Reset allowance failed");
            }
            // set new allowance
            require(loanToken.approve(lenderAccount, amountToLender), "Approval failed");
            IAccount(agreement.lenderAccount.addr).loadFromPosition(
            agreement.loanAsset,
            amountToLender,
            agreement.lenderAccount.parameters
        );

        }
    }

    function plant() external payable {
        address BEANSTALK = 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5;
        (uint256 beans,)=ISilo(BEANSTALK).plant();
        plantedBeans += beans;
    }

    function _unwind(Agreement calldata agreement) internal override {
        address BEANSTALK = 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5;
        address BEAN_ETH_WELL = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd;

        ISilo(BEANSTALK).withdrawDeposit(BEAN_ETH_WELL,stem,lpDeposit, LibTransfer.To.EXTERNAL);
        IWell(BEAN_ETH_WELL).removeLiquidityOneToken(lpDeposit,IERC20(C.WETH),0, agreement.position.addr, block.timestamp * 2);
        unwound = true;
       
        }

    function mow() external payable {
    address BEAN_ETH_WELL = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd;
    address BEANSTALK = 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5;
    ISilo(BEANSTALK).mow(address(this), BEAN_ETH_WELL);
    }

    // Public Helpers.

    function _getCloseAmount(Agreement memory agreement) internal  override returns (uint256) {
       if(unwound==true){
        (, int256 answer, , , ) = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419).latestRoundData();
        uint256 ethUsdValue = (uint256(answer) * C.RATIO_FACTOR) / (10 ** (8));
        uint256 amount = IERC20(C.WETH).balanceOf(agreement.position.addr);
        return ethUsdValue*amount/C.RATIO_FACTOR;
       } else {
       
        address BEAN_ETH_WELL = 0xBEA0e11282e2bB5893bEcE110cF199501e872bAd;
        address BEANSTALK = 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5;
        address BEAN_ORACLE = 0xB467BB2D164283a38eaAe615DD8e8Ecdbd1C89e9;
        uint256 earnedBeans = ISilo(BEANSTALK).balanceOfEarnedBeans(agreement.position.addr);
        uint256 wellLPBDV = ISilo(BEANSTALK).wellBdv(BEAN_ETH_WELL, lpDeposit);
        uint256 totalBDV = ((earnedBeans + wellLPBDV + plantedBeans) * C.RATIO_FACTOR) / 10 ** (6); //Total BDV in 18 dec precision
        uint256 closeAmount = (IOracle(BEAN_ORACLE).getOpenPrice(abi.encode(1), "") * (totalBDV)) / C.RATIO_FACTOR; // in USD
        return closeAmount;}


    }
}
