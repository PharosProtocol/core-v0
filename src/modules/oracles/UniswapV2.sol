// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {IOracle} from "src/interfaces/IOracle.sol";
import {OracleParameters} from "src/libraries/LibOracle.sol";

import "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// Path should start with USDC, end with asset of interest

interface IUniswapV2Oracle is IOracle {
    function decodeParameters(OracleParameters calldata oracleParams)
        external
        pure
        returns (Parameters memory params);
}

struct Parameters {
    address asset;
    address[] pathToUsd;
    address[] pathFromUsd;
    uint256 stepSlippageRatio;
}

/*
 * This is an implementation contract that represents one method of computing asset prices.
 * It will create a clone for each unique set of parameters used (path, slippage).
 * Modulus will interact directly with the clone using only the standard functions.
 */
contract UniswapV2Oracle is IUniswapV2Oracle {
    address private constant UNI_V2_ROUTER02 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    uint256 private constant RATIO_BASE = 1e18;
    uint256 private constant MAX_SLIPPAGE = 10; // 10% slippage

    function decodeParameters(OracleParameters calldata oracleParams) public pure returns (Parameters memory params) {
        params.asset = oracleParams.asset;
        (params.pathToUsd, params.pathFromUsd, params.stepSlippageRatio) =
            abi.decode(oracleParams.instanceParams, (address[], address[], uint256));
    }

    /// @notice verify that parameters are valid combination with this implementation. Users should be able to use
    ///         suboptimal values, but not outright invalid or hostile values.
    /// NOTE should call at position creation time, but gAs OpTImiZaTiONs will probably push it to UI
    function verifyParameters(OracleParameters calldata oracleParams) external view override {
        Parameters memory params = decodeParameters(oracleParams);

        require(params.asset == params.pathToUsd[0], "origin enter asset mismatch");
        require(params.asset == params.pathFromUsd[params.pathFromUsd.length - 1], "final exit asset mismatch");
        // NOTE should check that other end of path terminates in USDC?
        require(params.pathToUsd.length == params.pathFromUsd.length, "path length mismatch");
        for (uint256 i; i < params.pathToUsd.length; i++) {
            require(params.pathToUsd[i] == params.pathFromUsd[params.pathFromUsd.length - 1 - i], "path mismatch");
        }
        require(params.stepSlippageRatio < RATIO_BASE * MAX_SLIPPAGE, "slippage too high");
    }

    function getValue(uint256 amount, OracleParameters calldata oracleParams)
        external
        view
        override
        returns (uint256)
    {
        Parameters memory params = decodeParameters(oracleParams);
        IUniswapV2Router02 router = IUniswapV2Router02(UNI_V2_ROUTER02);
        uint256[] memory outAmounts = router.getAmountsOut(amount, params.pathToUsd);
        return outAmounts[outAmounts.length - 1] * (params.pathToUsd.length) * params.stepSlippageRatio / RATIO_BASE; // expect math here is wrong
    }

    function getAmount(uint256 value, OracleParameters calldata oracleParams)
        external
        view
        override
        returns (uint256)
    {
        Parameters memory params = decodeParameters(oracleParams);
        IUniswapV2Router02 router = IUniswapV2Router02(UNI_V2_ROUTER02);
        uint256[] memory outAmounts = router.getAmountsOut(value, params.pathFromUsd);
        return outAmounts[outAmounts.length - 1] * (params.pathFromUsd.length) * params.stepSlippageRatio / RATIO_BASE; // expect math here is wrong
    }
}
