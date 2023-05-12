// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "forge-std/console.sol";

import {C} from "src/C.sol";
import {Terminal} from "src/terminal/Terminal.sol";
import {IPosition} from "src/terminal/IPosition.sol";
import {Asset, ETH_STANDARD, ERC20_STANDARD} from "src/LibUtil.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// import {SwapCallbackData} from "lib/v3-periphery/contracts/SwapRouter.sol";
struct SwapCallbackData {
    bytes path;
    address payer;
}

/*
 * The Hold terminal simply holds assets and performs not actions with them. This allows users to long or short assets
 * as long as the necessary supply of their interested asset is available. This is similar to how existing lending
 * markets provided by protocols like Aave or Compound.
 */

contract HoldTerminal is Terminal {
    struct Parameters {}

    // Position state
    uint256 private amountHeld;

    constructor(address protocolAddr) Terminal(protocolAddr) {}

    /// @notice Do nothing.
    /// @dev assumes assets have already been transferred to Position.
    function _deploy(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        // Parameters memory params = abi.decode(parameters, (Parameters));
    }

    /// @notice Do nothing.
    function _exit(Asset memory exitAsset, bytes calldata parameters) internal override returns (uint256 exitAmount) {
        // Parameters memory params = abi.decode(parameters, (Parameters));
    }

    // Only used for transferring loan asset direct to user.
    function _transferLoanAsset(address payable to, Asset memory asset, uint256 amount) internal override {
        if (asset.standard == ETH_STANDARD) {
            // NOTE change to call and protec
            to.transfer(amount);
        } else if (asset.standard == ERC20_STANDARD) {
            IERC20(asset.addr).transfer(to, amount);
        } else {
            revert("Incompatible asset");
        }
    }

    // Public Helpers.

    function getExitAmount(Asset calldata, bytes calldata parameters) external view override returns (uint256) {
        return amountHeld;
    }

}
