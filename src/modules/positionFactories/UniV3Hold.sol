// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {PositionFactory} from "src/modules/PositionFactory.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {ISwapRouter} from "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "lib/v3-periphery/contracts/libraries/PoolAddress.sol";
import "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "lib/v3-core/contracts/libraries/TickMath.sol";
import "lib/v3-core/contracts/libraries/FixedPoint96.sol";
import "lib/v3-core/contracts/libraries/FullMath.sol";
import "lib/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "lib/v3-periphery/contracts/interfaces/IQuoter.sol";

import "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {BytesLib} from "lib/v3-periphery/contracts/libraries/BytesLib.sol";
import {Path} from "lib/v3-periphery/contracts/libraries/path.sol";
import {IUniswapV3Factory} from "lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {CallbackValidation} from "lib/v3-periphery/contracts/libraries/CallbackValidation.sol";

// import {SwapCallbackData} from "lib/v3-periphery/contracts/SwapRouter.sol";
struct SwapCallbackData {
    bytes path;
    address payer;
}

// import "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";

// (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

/*
 * This contract serves as a demonstration of how to implement a Modulus Terminal.
 * Terminals should be designed as Minimal Proxy Contracts with an arbitrary number of proxy contracts. Each MPC
 * represents one position that has been open through the Terminal. This allows for the capital of multiple positions
 * to remain isolated from each other even when deployed in the same terminal.
 *
 * The Terminal must implement at minimum the set of methods shown in the Modulus Terminal Interface. Beyond that,
 * a terminal can offer an arbitrary set of additional methods that act as wrappers for the underlying protocol;
 * however, the Modulend marketplace cannot be updated to support all possible actions in all possible terminals. Users
 * will automatically have the ability to call functions listed in the interface as well as any public functions that do
 * not require parameters. These additional argumentless function calls can be used to wrap functionality of the
 * underlying protocol to enable simple updating and interaction with a position - we recommend they are named in a
 * self documenting fashion, so that users can be programatically informed of their purpose. Further,
 * arbitrarily complex functions can be implemented, but the terminal creator will be responsible for providing a UI
 * to handle these interactions.
 *
 * NOTE for sake of efficiency, should split into multi-hop and single pool paths.
 */
contract UniV3HoldTerminal is PositionFactory {
    address public constant UNI_V3_FACTORY = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    address public constant UNI_V3_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    uint256 private constant RATIO_BASE = 1e18;

    // Terminal parameters
    uint32 private constant TRADE_TWAP_TIME = 300; // https://oracle.euler.finance
    uint32 private constant VALUE_TWAP_TIME = 60; // too short allows manipulation, too long increases risk to lender.
    uint256 private constant DEADLINE_OFFSET = 120;
    uint256 private constant ALLOWED_STEP_SLIPPAGE_RATIO = RATIO_BASE * 1 / 100;
    bytes private ENTER_PATH;
    bytes private EXIT_PATH;

    // Position state
    uint256 private amountHeld;

    event UniV3HoldPositionEntered(uint256 enterAmount, uint256 positionAmount);
    event UniV3HoldPositionExited(uint256 positionAmount, uint256 exitAmount); // position amount here redundant. can save gas by removing.

    using Path for bytes;
    using BytesLib for bytes;

    /**
     * @notice Send ERC20 assets that Uniswap expects for swap.
     * @dev see lib/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol
     * @param   amount0Delta 0 represents pool index (not directionality)
     * @param   amount1Delta 1 represents pool index (not directionality)
     * @param   data  .
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        SwapCallbackData memory swapCallbackData = abi.decode(data, (SwapCallbackData));
        require(swapCallbackData.payer == address(this));
        (address tokenIn, address tokenOut, uint24 fee) = swapCallbackData.path.decodeFirstPool(); // Token order is directionality?
        CallbackValidation.verifyCallback(UNI_V3_FACTORY, tokenIn, tokenOut, fee); // requires sender == pool

        // Uniswap V3 gas optimization is just pushing gas, along with complexity, onto protocol users. <3
        require(amount0Delta > 0 || amount1Delta > 0);
        uint256 amountToPay;
        if (amount0Delta > 0) {
            amountToPay = uint256(amount0Delta);
            require(tokenIn < tokenOut); // Must be exact input with tokenIn as token0
        } else {
            amountToPay = uint256(amount1Delta);
            require(tokenIn > tokenOut); // Must be exact input with tokenIn as token1
        }

        require(IERC20(tokenIn).transfer(address(msg.sender), amountToPay));
    }

    function enter(bytes calldata parameters) internal override initializer {
        (uint256 amountIn) = abi.decode(parameters, (uint256));
        ISwapRouter router = ISwapRouter(UNI_V3_ROUTER);
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
            path: ENTER_PATH,
            recipient: address(this), // position address
            deadline: block.timestamp + DEADLINE_OFFSET,
            amountIn: amountIn,
            amountOutMinimum: getPathTWAPQuote(ENTER_PATH, amountIn, TRADE_TWAP_TIME) * ALLOWED_STEP_SLIPPAGE_RATIO
                * ENTER_PATH.numPools() / RATIO_BASE
        });

        amountHeld = router.exactInput(swapParams); // msg.sender from router pov is clone (Position) address
        emit UniV3HoldPositionEntered(amountIn, amountHeld);
    }

    // TODO: can add recipient in certain scenarios to save an ERC20 transfer.
    // NOTE: How to liquidate if min acceptable price is uncontrollable? Better to liquidate at a bad price now than wait
    //       until volatility slows. Answer: Allow liquidator to pass in min price, but require them to return some
    //       amount. then if they give themselves a bad deal they are the only one who loses. Alt Answer: Allow
    //       liquidator to pass through any function via callback, so long as they return enough assets to Modulend
    //       lender / borrower in end.
    function exit(bytes calldata) external onlyRole(PROTOCOL_ROLE) returns (uint256 amountOut) {
        ISwapRouter router = ISwapRouter(UNI_V3_ROUTER);
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
            path: EXIT_PATH,
            recipient: address(this), // position address
            deadline: block.timestamp + DEADLINE_OFFSET,
            amountIn: amountHeld,
            amountOutMinimum: getPathTWAPQuote(EXIT_PATH, amountHeld, TRADE_TWAP_TIME) * ALLOWED_STEP_SLIPPAGE_RATIO
                * EXIT_PATH.numPools() / RATIO_BASE
        });

        amountOut = router.exactInput(swapParams); // msg.sender from router pov is clone (Position) address
        emit UniV3HoldPositionExited(amountHeld, amountOut);
    }

    /// Get the TWAP of the pool across interval. token1/token0.
    /// NOTE: Could really use a more experienced set of eyes on this. So much potential for arithmetic errors.
    function getTWAPQuote(address pool, uint256 amount, address tokenIn, address tokenOut, uint32 twapTime)
        private
        view
        returns (uint256)
    {
        // (int56[] memory tickCumulatives,) = IUniswapV3Pool(pool).observe([twapTime, 0]);
        // uint256 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        // int24 arithmeticMeanTick = int24(tickCumulativesDelta / twapTime);
        // // Always round towards negative infinity
        // if (tickCumulativesDelta < 0 && (tickCumulativesDelta % twapTime != 0)) arithmeticMeanTick--;

        (int24 arithmeticMeanTick,) = OracleLibrary.consult(pool, twapTime);

        // uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(arithmeticMeanTick); // why does observe return int56 and then this, the obvious followup, requires int24?
        // return FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, FixedPoint96.Q96); // so heavy handed. wen wells?
        // NOTE: is conversion to uint128 safe and reliable?
        return OracleLibrary.getQuoteAtTick(arithmeticMeanTick, uint128(amount), tokenIn, tokenOut); // forced to downsize to uint128 so that we can usee univ3 method of precision? Seems dangerous if number is big.
    }

    /// Not cheap, due to repeated external calls.
    function getPathTWAPQuote(bytes storage path, uint256 amount, uint32 twapTime) private view returns (uint256) {
        for (uint256 i = 0; i < path.numPools(); i++) {
            (address tokenIn, address tokenOut, uint24 fee) = path.decodeFirstPool();
            address pool = PoolAddress.computeAddress(UNI_V3_FACTORY, PoolAddress.getPoolKey(tokenIn, tokenOut, fee));
            amount = getTWAPQuote(pool, amount, tokenIn, tokenOut, twapTime);
        }
        return amount;
    }

    // Public Helpers.

    /// Expected to be used off-chain.
    function getValue() external view override returns (uint256) {
        return getPathTWAPQuote(EXIT_PATH, amountHeld, VALUE_TWAP_TIME);
    }
}
