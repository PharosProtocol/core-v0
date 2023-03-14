// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {IOracle} from "src/modules/oracles/IOracle.sol";

import "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// Path should start with USDC, end with asset of interest

interface IUniswapV2Oracle is IOracle {
    function decodeParameters(bytes calldata parameters)
        external
        pure
        returns (address[] pathToUsd, address[] pathFromUsd, uint256 stepSlippageRatio);
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

    function decodeParameters(bytes calldata parameters) public pure returns (address[], address[], uint256) {
        return abi.decode(parameters, (address[], address[], uint256));
    }

    /// @notice verify that parameters are valid combination with this implementation. Users should be able to use
    ///         suboptimal values, but not outright invalid or hostile values.
    /// NOTE should call at position creation time, but gAs OpTImiZaTiONs will probably push it to UI
    function verifyParameters(bytes calldata parameters) external view override {
        (address[] pathToUsd, address[] pathFromUsd, uint256 stepSlippageRatio) = decodeParameters(parameters);
        for (uint256 i; i < pathToUsd.length; i++) {
            require(pathToUsd[i] == pathFromUsd[endPath.length - 1 - i], "path mismatch");
        }
        require(stepSlippageRatio < RATIO_BASE * MAX_SLIPPAGE, "slippage too high");
    }

    function getValue(uint256 amount, bytes calldata parameters) external view override returns (uint256) {
        IUniswapV2Router02 router = IUniswapV2Router02(UNI_V2_ROUTER02);
        (address[] pathToUsd,, uint256 stepSlippageRatio) = decodeParameters(parameters);
        uint256[] memory outAmounts = router.getAmountsOut(amount, pathToUsd);
        return outAmounts[outAmounts.length - 1] * (pathToUsd.length) * stepSlippageRatio / RATIO_BASE; // expect math here is wrong
    }

    function getAmount(uint256 value, bytes calldata parameters) external view override returns (uint256) {
        IUniswapV2Router02 router = IUniswapV2Router02(UNI_V2_ROUTER02);
        (, address[] pathFromUsd, uint256 stepSlippageRatio) = decodeParameters(parameters);
        uint256[] memory outAmounts = router.getAmountsOut(value, pathFromUsd);
        return outAmounts[outAmounts.length - 1] * (pathFromUsd.length) * stepSlippageRatio / RATIO_BASE; // expect math here is wrong
    }
}
