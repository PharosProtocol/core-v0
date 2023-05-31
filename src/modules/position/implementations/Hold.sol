// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "forge-std/console.sol";

import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {C} from "src/C.sol";
import {Position} from "src/modules/position/Position.sol";
import {Asset, ETH_STANDARD, ERC20_STANDARD} from "src/LibUtil.sol";
import {Module} from "src/modules/Module.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// import {SwapCallbackData} from "lib/v3-periphery/contracts/SwapRouter.sol";
struct SwapCallbackData {
    bytes path;
    address payer;
}

/*
 * The Hold Factory simply holds assets and performs no actions with them. This allows users to long or short assets
 * as long as the necessary supply of their interested asset is available. This is similar to how existing lending
 * markets provided by protocols like Aave or Compound.
 *
 * NOTE This is only useful as an undercollateralized position where assets can be sent to user wallet. Not intending
 * to support in v1.
 */

contract HoldFactory is Position {
    // struct Parameters {}

    // Position state
    uint256 private amountHeld;

    constructor(address protocolAddr) Position(protocolAddr) {
        // COMPATIBLE_LOAN_ASSETS.push(Asset({standard: ERC20_STANDARD, addr: address(0), id: 0, data: ""}));
        // COMPATIBLE_COLL_ASSETS.push(Asset({standard: ERC20_STANDARD, addr: address(0), id: 0, data: ""}));
    }

    /// @notice Do nothing.
    /// @dev assumes assets have already been transferred to Position.
    function _deploy(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        // Parameters memory params = abi.decode(parameters, (Parameters));
    }

    /// @notice Do nothing.
    function _exit(address sender, Agreement calldata agreement, bytes calldata parameters) internal override {
        // Parameters memory params = abi.decode(parameters, (Parameters));
    }

    // Public Helpers.

    function getExitAmount(bytes calldata) external view override returns (uint256) {
        return amountHeld;
    }

    function canHandleAsset(Asset calldata asset, bytes calldata) external pure override returns (bool) {
        if (asset.standard != ERC20_STANDARD) return false;
        return true;
    }
}
