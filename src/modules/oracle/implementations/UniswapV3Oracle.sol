// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {IOracle} from "../IOracle.sol";

import {C} from "src/C.sol";
import {Asset, ETH_STANDARD} from "src/LibUtil.sol";
import {LibUniswapV3} from "src/util/LibUniswapV3.sol";
import {Path} from "lib/v3-periphery/contracts/libraries/path.sol";
import {BytesLib} from "lib/v3-periphery/contracts/libraries/BytesLib.sol";

contract UniswapV3Oracle is IOracle {
    struct Parameters {
        bytes pathFromUsd;
        bytes pathToUsd;
        uint256 stepSlippageRatio;
        uint32 twapTime;
    }

    using Path for bytes;
    using BytesLib for bytes;

    // uint256 private constant MAX_SLIPPAGE = C.RATIO_FACTOR / 10; // 10% slippage

    /// @notice verify that parameters are valid combination with this implementation. Users should be able to use
    ///         suboptimal values, but not outright invalid or hostile values.
    /// NOTE should call at position creation time, but gAs OpTImiZaTiONs will probably push it to UI
    /// NOTE ^^ alternatively pass in arguments to below functions which are verified at runtime, like asset. this
    ///         guards against using a terminal maliciously and removes need to ensure compatibility between
    ///         agreement fields and encoded bytes of module parameters.
    function verifyParameters(Asset calldata, bytes calldata parameters) external pure override {
        Parameters memory params = abi.decode(parameters, (Parameters));

        // require(asset == address(bytes20(params.pathToUsd.slice(0, 20))), "origin enter asset mismatch");
        // require(
        //     asset
        //         == address(bytes20(params.pathFromUsd.slice(43 * (params.pathFromUsd.numPools() - 1) + 23, 20))),
        //     "final exit asset mismatch"
        // );
        require(params.pathToUsd.numPools() == params.pathFromUsd.numPools(), "path length mismatch");
        // // Verify pools AND fees match
        // for (uint256 i; i < params.pathToUsd.length; i++) {
        //     require(params.pathToUsd[i] == params.pathFromUsd[params.pathFromUsd.length - 1 - i], "path mismatch");
        // }
    }

    /// @dev Does not account for slippage.
    function getValue(Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        view
        override
        returns (uint256)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));
        (address assetAddr,,) = params.pathToUsd.decodeFirstPool();
        if (asset.standard == ETH_STANDARD) {
            require(assetAddr == C.WETH, "Uniswap V3 Oracle: eth asset mismatch");
        } else {
            require(asset.addr == assetAddr, "Uniswap V3 Oracle: getValue asset mismatch");
        }
        return LibUniswapV3.getPathTWAP(params.pathToUsd, amount, params.twapTime);
    }

    /// @dev value is amount of the accounting token.
    function getAmount(Asset calldata asset, uint256 value, bytes calldata parameters)
        external
        view
        override
        returns (uint256)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));
        (address assetAddr,,) = params.pathToUsd.decodeFirstPool();
        if (asset.standard == ETH_STANDARD) {
            require(assetAddr == C.WETH, "Uniswap V3 Oracle: eth asset mismatch");
        } else {
            require(asset.addr == assetAddr, "Uniswap V3 Oracle: getValue asset mismatch");
        }
        return LibUniswapV3.getPathTWAP(params.pathFromUsd, value, params.twapTime);
    }
}
