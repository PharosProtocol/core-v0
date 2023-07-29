// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Asset, PluginRef} from "src/libraries/LibUtils.sol";

/**
 * Any plugin that can hold assets is an AssetHolder - i.e. ports and terminals.
 * The functionality offered by this interface allows for plugins to handle the receipt of assets without
 * understanding that asset by performing a delegatecall callback to the appropriate Freighter. Only bookkeepers
 * can trigger a receipt process.
 * This is useful for assets that have complex logic, like staking when inside of a port which
 * should be implemented in the freighter itself but needs access to the holder state.
 *
 * AssetHolder plugins should not attempt to keep track of all asset inflows, as
 * there may be unexpected fluctuations in balance (from position profits, rebasing tokens, etc).
 */

interface IAssetHolder {
    function processReceipt(
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external;
}
