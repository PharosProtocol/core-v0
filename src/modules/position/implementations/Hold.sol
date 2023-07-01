// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {C} from "src/libraries/C.sol";
import {Position} from "src/modules/position/Position.sol";
import {Asset, ETH_STANDARD, ERC20_STANDARD} from "src/libraries/LibUtils.sol";
import {Module} from "src/modules/Module.sol";

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

    constructor(address protocolAddr) Position(protocolAddr) {}

    /// @notice Do nothing.
    /// @dev assumes assets have already been transferred to Position.
    function _deploy(Asset calldata, uint256, bytes calldata) internal override {
        // Parameters memory params = abi.decode(parameters, (Parameters));
    }

    /// @notice Do nothing.
    function _close(address, Agreement calldata, bool, bytes calldata)
        internal
        pure
        override
        returns (uint256 closedAmount)
    {
        // Parameters memory params = abi.decode(parameters, (Parameters));
        return 0;
    }

    // Public Helpers.

    function _getCloseAmount(bytes calldata) internal view override returns (uint256) {
        return amountHeld;
    }

    function canHandleAsset(Asset calldata asset, bytes calldata) external pure override returns (bool) {
        if (asset.standard != ERC20_STANDARD) return false;
        return true;
    }
}
