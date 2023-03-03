// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {Factory} from "src/modules/Factory.sol";
import {IOracle} from "src/modules/OracleFactory.sol";

import "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// NOTE: Should define argument invariants to confirm that clones are valid for UI.
/// Path should start with USDC, end with asset of interest

/*
 * This is an implementation contract that represents one method of computing asset prices.
 * It will create a clone for each unique set of parameters used (path, slippage).
 * Modulus will interact directly with the clone using only the standard functions.
 */
contract UniswapV2Oracle is IOracle, Factory {
    address private constant UNI_V2_ROUTER02 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    uint256 private constant RATIO_BASE = 1e18;

    // Full trading path to follow through Uniswap V2.
    address[] private path;
    // Max allowed slippage at each step of path.
    uint256 private stepSlippageRatio;

    function initialize(bytes calldata parameters) external override initializer {
        (path, stepSlippageRatio) = abi.decode(parameters, (address[], uint256));
    }

    function getValue(uint256 amount) external view override returns (uint256) {
        IUniswapV2Router02 router = IUniswapV2Router02(UNI_V2_ROUTER02);
        uint256[] memory outAmounts = router.getAmountsOut(amount, path);
        return outAmounts[outAmounts.length - 1] * (outAmounts.length - 1) * stepSlippageRatio / RATIO_BASE;
    }
}
