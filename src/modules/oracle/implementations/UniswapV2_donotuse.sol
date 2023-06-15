// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 *
 * DO NOT USE THIS ORACLE
 * It is susceptible to oracle manipulation attacks since it does not use average price over a period of time.
 *
 */

/*

import {IOracle} from "src/interfaces/IOracle.sol";

import {C} from "src/libraries/C.sol";
import "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// Path should start with USDC, end with asset of interest

struct Parameters {
    address[] pathToUsd;
    address[] pathFromUsd;
    uint256 stepSlippageRatio;
}


//  * This is an implementation contract that represents one method of computing asset prices.
//  * It will create a clone for each unique set of parameters used (path, slippage).
//  * Modulus will interact directly with the clone using only the standard functions.
 
contract UniswapV2Oracle is IOracle {
    address private constant UNI_V2_ROUTER02 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    uint256 private constant MAX_SLIPPAGE = 10; // 10% slippage

    /// @notice verify that parameters are valid combination with this implementation. Users should be able to use
    ///         suboptimal values, but not outright invalid or hostile values.
    /// NOTE should call at position creation time, but gAs OpTImiZaTiONs will probably push it to UI
    /// NOTE ^^ alternatively pass in arguments to below functions which are verified at runtime, like asset. this
    ///         guards against using a factory maliciously and removes need to ensure compatibility between
    ///         agreement fields and encoded bytes of module parameters.
    function verifyParameters(address asset, bytes calldata parameters) external pure override {
        Parameters memory params = abi.decode(parameters, (Parameters));

        require(asset == params.pathToUsd[0], "origin enter asset mismatch");
        require(asset == params.pathFromUsd[params.pathFromUsd.length - 1], "final exit asset mismatch");
        // NOTE should check that other end of path terminates in USDC?
        require(params.pathToUsd.length == params.pathFromUsd.length, "path length mismatch");
        for (uint256 i; i < params.pathToUsd.length; i++) {
            require(params.pathToUsd[i] == params.pathFromUsd[params.pathFromUsd.length - 1 - i], "path mismatch");
        }
        require(params.stepSlippageRatio < C.RATIO_FACTOR * MAX_SLIPPAGE, "slippage too high");
    }

    function getValue(uint256 amount, bytes calldata parameters) external view override returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        IUniswapV2Router02 router = IUniswapV2Router02(UNI_V2_ROUTER02);
        // require(asset == params.pathToUsd[0], "origin enter asset mismatch");
        uint256[] memory outAmounts = router.getAmountsOut(amount, params.pathToUsd);
        return outAmounts[outAmounts.length - 1] * (params.pathToUsd.length) * params.stepSlippageRatio / C.RATIO_FACTOR; // expect math here is wrong
    }

    function getAmount(uint256 value, bytes calldata parameters) external view override returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        IUniswapV2Router02 router = IUniswapV2Router02(UNI_V2_ROUTER02);
        // require(asset == params.pathFromUsd[0], "origin enter asset mismatch");
        uint256[] memory outAmounts = router.getAmountsOut(value, params.pathFromUsd);
        return
            outAmounts[outAmounts.length - 1] * (params.pathFromUsd.length) * params.stepSlippageRatio / C.RATIO_FACTOR; // expect math here is wrong
    }
}
*/
