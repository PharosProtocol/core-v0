// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Oracle} from "../Oracle.sol";

import {Path} from "@uni-v3-periphery/libraries/path.sol";
import {BytesLib} from "@uni-v3-periphery/libraries/BytesLib.sol";

import {C} from "src/libraries/C.sol";
import {Asset, ETH_STANDARD, ERC20_STANDARD} from "src/libraries/LibUtils.sol";
import {LibUniswapV3} from "src/libraries/LibUniswapV3.sol";

contract UniswapV3Oracle is Oracle {
    struct Parameters {
        bytes pathFromEth;
        bytes pathToEth;
        uint32 twapTime;
        uint64 stepSlippage;
    }

    using Path for bytes;
    using BytesLib for bytes;

    constructor() {}

    function getResistantValue(uint256 amount, bytes calldata parameters) external view returns (uint256 value) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        return
            (LibUniswapV3.getPathTWAP(params.pathToEth, amount, params.twapTime) *
                (C.RATIO_FACTOR - params.stepSlippage * params.pathToEth.numPools())) / C.RATIO_FACTOR;
    }

    function getSpotValue(uint256 amount, bytes calldata parameters) external view returns (uint256 value) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        return
            (LibUniswapV3.getPathSpotPrice(params.pathToEth, amount) *
                (C.RATIO_FACTOR - params.stepSlippage * params.pathToEth.numPools())) / C.RATIO_FACTOR;
    }

    function getResistantAmount(uint256 value, bytes calldata parameters) external view returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        return
            (LibUniswapV3.getPathTWAP(params.pathFromEth, value, params.twapTime) *
                (C.RATIO_FACTOR - params.stepSlippage * params.pathFromEth.numPools())) / C.RATIO_FACTOR;
    }

    /// @notice verify that parameters are valid combination with this implementation. Users should be able to use
    ///         suboptimal values, but not outright invalid values.
    /// NOTE should call at position creation time, but gAs OpTImiZaTiONs will probably push it to UI
    /// NOTE ^^ alternatively pass in arguments to below functions which are verified at runtime, like asset. this
    ///         guards against using a factory maliciously and removes need to ensure compatibility between
    ///         agreement fields and encoded bytes of module parameters.
    function canHandleAsset(Asset calldata asset, bytes calldata parameters) external pure override returns (bool) {
        Parameters memory params = abi.decode(parameters, (Parameters));

        address assetAddr;
        if (asset.standard == ERC20_STANDARD) {
            assetAddr = asset.addr;
        } else if (asset.standard == ETH_STANDARD) {
            assetAddr = C.WETH;
        } else {
            return false;
        }

        if (assetAddr != params.pathToEth.toAddress(0)) return false;
        if (assetAddr != params.pathFromEth.toAddress(params.pathFromEth.length - 20)) return false;

        return true;
    }
}
