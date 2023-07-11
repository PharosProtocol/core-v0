// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "lib/forge-std/src/console.sol";

import {C} from "src/libraries/C.sol";
import {IUniswapV3Pool} from "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3PoolState} from "lib/v3-core/contracts/interfaces/pool/IUniswapV3PoolState.sol";
import {PoolAddress} from "lib/v3-periphery/contracts/libraries/PoolAddress.sol";
import {OracleLibrary} from "lib/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {Path} from "lib/v3-periphery/contracts/libraries/path.sol";
import "src/libraries/LibUtils.sol";

// reference of similar logic https://github.com/butterymoney/molten-oracle/blob/main/contracts/libraries/UniswapV3OracleConsulter.sol

// NOTE: Could really use another set of eyes on this. So much potential for arithmetic errors.

/// @notice Utilities for using Uniswap V3 as an oracle.
library LibUniswapV3 {
    using Path for bytes;

    // AUDIT use of uint128 vs 256. Uni v3 forces uint128, is it large enough for all reasonable ERC20s?

    // NOTE slight precision loss on spot price from using tick.
    function getPathSpotPrice(bytes memory path, uint256 amount) internal view returns (uint256) {
        return (getPathTWAP(path, amount, 0));
    }

    /// @dev Probably not cheap for long paths, due to repeated external calls.
    function getPathTWAP(bytes memory path, uint256 amount, uint32 twapTime) internal view returns (uint256) {
        // Optimize for bad sol loop init var memory handling
        address tokenIn;
        address tokenOut;
        uint24 fee;
        uint256 pathLength = path.numPools();
        require(pathLength > 0, "getPathTWAP: Empty path provided");
        require(amount < type(uint128).max, "getPathTWAP: amount uint128 overflow");
        uint128 amount128 = uint128(amount);
        if (pathLength == 1) {
            (tokenIn, tokenOut, fee) = path.decodeFirstPool();
            address pool = PoolAddress.computeAddress(C.UNI_V3_FACTORY, PoolAddress.getPoolKey(tokenIn, tokenOut, fee));
            return OracleLibrary.getQuoteAtTick(getTWATick(pool, twapTime), uint128(amount128), tokenIn, tokenOut); // twap
        } else {
            address[] memory tokens = new address[](pathLength + 1);
            int24[] memory ticks = new int24[](pathLength);
            // AUDIT is it necessary to factor in tick spacing?
            for (uint256 i = 0; i < pathLength; i++) {
                (tokenIn, tokenOut, fee) = path.decodeFirstPool();
                tokens[i] = tokenIn;
                // console.log("tokenIn: %s, tokenOut: %s, fee: %s", tokenIn, tokenOut, fee);
                address pool = PoolAddress.computeAddress(
                    C.UNI_V3_FACTORY,
                    PoolAddress.getPoolKey(tokenIn, tokenOut, fee)
                );
                // console.log("pool: %s", pool);
                // Computation depends on PoolAddress.POOL_INIT_CODE_HASH. Default value in Uni repo may not be correct.
                ticks[i] = getTWATick(pool, twapTime);
                // = getTWAP(pool, amount, tokenIn, tokenOut, twapTime);
                path = path.skipToken();
            }
            tokens[pathLength] = tokenOut;

            int256 chainedMeanTick = OracleLibrary.getChainedPrice(tokens, ticks);

            // AUDIT how to handle ticks outside this range? Pre-square root to make smaller?
            require(chainedMeanTick <= type(int24).max, "getPathTWAP: tick overflow");
            require(chainedMeanTick >= type(int24).min, "getPathTWAP: tick underflow");
            return
                OracleLibrary.getQuoteAtTick(int24(chainedMeanTick), uint128(amount128), tokens[0], tokens[pathLength]); // twap
        }
    }

    /// Get the TWAP of the pool across interval. token1/token0.
    function getTWATick(address pool, uint32 twapTime) internal view returns (int24 arithmeticMeanTick) {
        if (twapTime == 0) {
            (, arithmeticMeanTick, , , , , ) = IUniswapV3PoolState(pool).slot0();
        } else {
            require(LibUtils.isDeployedContract(pool), "Invalid pool, no contract at address");
            require(
                OracleLibrary.getOldestObservationSecondsAgo(pool) >= twapTime,
                "UniV3 pool observations too young"
            ); // ensure needed data is available
            // console.log("oldest observation seconds ago: %s", OracleLibrary.getOldestObservationSecondsAgo(pool));
            (, , , uint16 observationCardinality, , , ) = IUniswapV3PoolState(pool).slot0();
            require(observationCardinality >= twapTime / 12, "UniV3 pool cardinality too low"); // shortest case scenario should always cover twap time
            (arithmeticMeanTick, ) = OracleLibrary.consult(pool, twapTime);
            // console.log("arithmeticMeanTick:");
            // console.logInt(arithmeticMeanTick);
        }
    }
}
