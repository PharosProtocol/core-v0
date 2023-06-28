// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Oracle} from "../Oracle.sol";

import {C} from "src/libraries/C.sol";
import {Asset, ETH_STANDARD, ERC20_STANDARD} from "src/libraries/LibUtils.sol";
import {LibUniswapV3} from "src/libraries/LibUniswapV3.sol";
import {Path} from "lib/v3-periphery/contracts/libraries/path.sol";
import {BytesLib} from "lib/v3-periphery/contracts/libraries/BytesLib.sol";

contract UniswapV3Oracle is Oracle {
    struct Parameters {
        bytes pathFromUsd;
        bytes pathToUsd;
        uint256 stepSlippageRatio;
        uint32 twapTime;
    }

    using Path for bytes;
    using BytesLib for bytes;

    constructor() {}

    // uint256 private constant MAX_SLIPPAGE = C.RATIO_FACTOR / 10; // 10% slippage

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
            require(assetAddr == C.WETH, "Uniswap V3 Oracle: getValue eth asset mismatch");
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
            require(assetAddr == C.WETH, "Uniswap V3 Oracle: getAmount eth asset mismatch");
        } else {
            require(asset.addr == assetAddr, "Uniswap V3 Oracle: getAmount asset mismatch");
        }
        return LibUniswapV3.getPathTWAP(params.pathFromUsd, value, params.twapTime);
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

        if (assetAddr != params.pathToUsd.toAddress(0)) return false;
        if (assetAddr != params.pathFromUsd.toAddress(params.pathFromUsd.length - 20)) return false;

        return true;
    }
}
