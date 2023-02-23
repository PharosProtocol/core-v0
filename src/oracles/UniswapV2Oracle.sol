// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// approx deployment cost: ~583,744 gas

/// Adheres to IOracle located in "src/modulus/Oracle.sol"
contract UniswapV2Oracle {
    address private constant UNI_V2_ROUTER02 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    uint256 private constant RATIO_BASE = 1e18;

    function getValue(bytes calldata data) external view returns (uint256) {
        (uint256 amountIn, address[] memory path, uint256 stepSlippageRatio) =
            abi.decode(data, (uint256, address[], uint256));
        IUniswapV2Router02 router = IUniswapV2Router02(UNI_V2_ROUTER02);
        uint256[] memory outAmounts = router.getAmountsOut(amountIn, path);
        return outAmounts[outAmounts.length - 1] * (outAmounts.length - 1) * stepSlippageRatio / RATIO_BASE;
    }
}
