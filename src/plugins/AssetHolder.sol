// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IAssetHolder} from "src/interfaces/IAssetHolder.sol";
import {IFreighter} from "src/interfaces/IFreighter.sol";
import {Asset, PluginRef} from "src/libraries/LibUtils.sol";
import {C} from "src/libraries/C.sol";

abstract contract AssetHolder is AccessControl {
    enum PluginCategory {
        NULL,
        PORT,
        TERMINAL
    }

    PluginCategory public immutable pluginCategory;

    constructor(address bookkeeperAddr, PluginCategory category) {
        _setupRole(C.BOOKKEEPER_ROLE, bookkeeperAddr);
        pluginCategory = category;
    }

    function processReceipt(
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external onlyRole(C.BOOKKEEPER_ROLE) {
        _processReceipt(asset, amount, parameters);

        // Allow the freighter to handle asset-specific logic in the state space of the holding plugin.
        bytes memory callData;
        if (pluginCategory == PluginCategory.PORT) {
            callData = abi.encodeWithSelector(
                IFreighter.portReceiptCallback.selector,
                asset,
                amount,
                pluginCategory,
                freighter.parameters
            );
        } else if (pluginCategory == PluginCategory.TERMINAL) {
            callData = abi.encodeWithSelector(
                IFreighter.terminalReceiptCallback.selector,
                asset,
                amount,
                pluginCategory,
                freighter.parameters
            );
        } else {
            revert("invalid receipt plugin category");
        }

        (bool success, ) = freighter.addr.delegatecall(callData);
        require(success, "failed freighter callback");
    }

    /// @notice Plugin reacts to the receipt of assets. Optional.
    function _processReceipt(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;
}
