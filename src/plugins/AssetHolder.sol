// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IAssetHolder} from "src/interfaces/IAssetHolder.sol";
import {IFreighter} from "src/interfaces/IFreighter.sol";
import {Asset, PluginRef} from "src/libraries/LibUtils.sol";
import {C} from "src/libraries/C.sol";

abstract contract AssetHolder is AccessControl, CloneFactory {
    AddrCategory public immutable addrCategory;

    constructor(address bookkeeperAddr, AddrCategory category) CloneFactory(bookkeeperAddr) {
        addrCategory = category;
    }

    function processReceipt(
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        bool isColl
    ) external proxyExecution onlyRole(C.BOOKKEEPER_ROLE) {
        _processReceipt(freighter, asset, amount, isColl);
    }

    function _processReceipt(
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        bool isColl
    ) internal proxyExecution {
        // __processReceipt(asset, amount, parameters);

        // Allow the freighter to handle asset-specific logic in the state space of the holding plugin.
        bytes memory callData;
        if (addrCategory == AddrCategory.PORT) {
            callData = abi.encodeWithSelector(
                IFreighter.portReceiptCallback.selector,
                asset,
                amount,
                freighter.parameters
            );
        } else if (addrCategory == AddrCategory.TERMINAL) {
            callData = abi.encodeWithSelector(
                IFreighter.termReceiptCallback.selector,
                asset,
                amount,
                isColl,
                freighter.parameters
            );
        } else {
            revert("invalid receipt plugin category");
        }

        (bool success, ) = freighter.addr.delegatecall(callData);
        require(success, "failed freighter callback");
    }

    // /// @notice Plugin reacts to the receipt of assets. Optional.
    // function __processReceipt(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;
}
