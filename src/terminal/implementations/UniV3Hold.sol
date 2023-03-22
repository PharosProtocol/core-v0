// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {Terminal} from "src/terminal/Terminal.sol";
import {IPosition} from "src/terminal/IPosition.sol";

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

// See v3-periphery/contracts/libraries/path.sol for bytes usage
interface IUniV3HoldTerminal is IPosition {
    function decodeParameters(bytes calldata parameters)
        external
        pure
        returns (bytes memory enterPath, bytes memory exitPath);
}

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
contract UniV3HoldTerminal is Terminal {
    address public constant UNI_V3_FACTORY = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    address public constant UNI_V3_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    uint256 private constant RATIO_BASE = 1e18;

    // Terminal parameters shared for all positions.
    // NOTE sharing params here increases simplicity but costs position customizability. how much of a burden is it to
    //      have very large parameters set in each order? that will probably dictate how we want to handle this.
    //      Also, setting them here prevents a position creator from setting them in a hostile fashion.
    uint32 private constant TRADE_TWAP_TIME = 300; // https://oracle.euler.finance
    uint32 private constant VALUE_TWAP_TIME = 60; // too short allows manipulation, too long increases risk to lender.
    uint256 private constant DEADLINE_OFFSET = 120;
    uint256 private constant ALLOWED_STEP_SLIPPAGE_RATIO = RATIO_BASE / 10; // 0.1% slippage ?

    // Position state
    uint256 private amountHeld;

    using Path for bytes;
    using BytesLib for bytes;

    function decodeParameters(bytes calldata parameters) public pure returns (bytes memory, bytes memory) {
        return abi.decode(parameters, (bytes, bytes));
    }

    /**
     * @notice Send ERC20 assets that Uniswap expects for swap.
     * @dev see lib/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol
     * @param   amount0Delta 0 represents pool index (not directionality)
     * @param   amount1Delta 1 represents pool index (not directionality)
     * @param   parameters  .
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata parameters) external {
        SwapCallbackData memory swapCallbackData = abi.decode(parameters, (SwapCallbackData));
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

    function _enter(address, uint256 amount, bytes calldata parameters) internal override {
        (bytes memory enterPath,) = decodeParameters(parameters);
        ISwapRouter router = ISwapRouter(UNI_V3_ROUTER);
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
            path: enterPath,
            recipient: address(this), // position address
            deadline: block.timestamp + DEADLINE_OFFSET,
            amountIn: amount,
            amountOutMinimum: (
                getPathTWAPQuote(enterPath, amount, TRADE_TWAP_TIME) * ALLOWED_STEP_SLIPPAGE_RATIO * enterPath.numPools()
                ) / RATIO_BASE
        });

        amountHeld = router.exactInput(swapParams); // msg.sender from router pov is clone (Position) address
            // return amountHeld; // can a named return value be used with a state variable?
    }

    // TODO: can add recipient in certain scenarios to save an ERC20 transfer.
    // NOTE: How to liquidate if min acceptable price is uncontrollable? Better to liquidate at a bad price now than wait
    //       until volatility slows. Answer: Allow liquidator to pass in min price, but require them to return some
    //       amount. then if they give themselves a bad deal they are the only one who loses. Alt Answer: Allow
    //       liquidator to pass through any function via callback, so long as they return enough assets to Modulend
    //       lender / borrower in end.
    function _exit(bytes calldata parameters) internal override returns (uint256) {
        (, bytes memory exitPath) = decodeParameters(parameters);
        ISwapRouter router = ISwapRouter(UNI_V3_ROUTER);
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
            path: exitPath,
            recipient: address(this), // position address
            deadline: block.timestamp + DEADLINE_OFFSET,
            amountIn: amountHeld,
            amountOutMinimum: (
                getPathTWAPQuote(exitPath, amountHeld, TRADE_TWAP_TIME) * ALLOWED_STEP_SLIPPAGE_RATIO * exitPath.numPools()
                ) / RATIO_BASE
        });

        return router.exactInput(swapParams); // msg.sender from router pov is clone (Position) address
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
    function getPathTWAPQuote(bytes memory path, uint256 amount, uint32 twapTime) private view returns (uint256) {
        for (uint256 i = 0; i < path.numPools(); i++) {
            (address tokenIn, address tokenOut, uint24 fee) = path.decodeFirstPool();
            address pool = PoolAddress.computeAddress(UNI_V3_FACTORY, PoolAddress.getPoolKey(tokenIn, tokenOut, fee));
            amount = getTWAPQuote(pool, amount, tokenIn, tokenOut, twapTime);
        }
        return amount;
    }

    // Public Helpers.

    /// @dev Expected to be used off-chain
    function getValue(bytes calldata parameters) external view override returns (uint256) {
        (, bytes memory exitPath) = decodeParameters(parameters);
        return getPathTWAPQuote(exitPath, amountHeld, VALUE_TWAP_TIME);
    }
}
