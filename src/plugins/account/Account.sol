// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IAccount} from "src/interfaces/IAccount.sol";
import {C} from "src/libraries/C.sol";
import {Asset, PluginRef} from "src/libraries/LibUtils.sol";
import {AssetHolder} from "src/plugins/AssetHolder.sol";

abstract contract Account is IAccount, ReentrancyGuard, AssetHolder {
    address public owner;

    event Loaded(address from, Asset asset, uint256 amount, bytes parameters);
    event Unloaded(Asset asset, uint256 amount, bytes parameters);
    event SentToPosition(address position, Asset asset, uint256 amount, bytes parameters);

    /// @dev Constructor is executed on implementation contract.
    constructor(address bookkeeperAddr) AssetHolder(bookkeeperAddr, category) {}

    // // NOTE need to deterministically predict clone addr so user can approve transfer
    // /// @dev Does not need to be redefined in each impl.
    // function loadViaBookkeeper(
    //     address sender,
    //     PluginRef calldata freighter,
    //     Asset calldata asset,
    //     uint256 amount,
    //     bytes calldata parameters
    // ) external payable onlyRole(C.BOOKKEEPER_ROLE) {
    //     _load(sender, freighter, asset, amount, parameters);
    //     _processReceipt(freighter, asset, amount, false);
    //     emit Loaded(asset, amount, parameters);
    // }

    function load(
        address from,
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external payable override onlyRole(C.BOOKKEEPER_ROLE) {
        _load(from, freighter, asset, amount, parameters);
        pull(from, freighter, asset, amount, AssetState.PORT, parameters);
        _processReceipt(freighter, asset, amount, AssetState.USER, AssetState.PORT);
        emit Loaded(asset, amount, parameters);
    }

    function unload(
        address to,
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external override nonReentrant {
        _unload(freighter, asset, amount, parameters);
        push(to, freighter, asset, amount, AssetState.PORT);
        emit Unloaded(asset, amount, parameters);
    }

    function sendToPosition(
        address to,
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external override onlyRole(C.BOOKKEEPER_ROLE) {
        _sendToPosition(position, freighter, asset, amount, parameters);
        push(to, freighter, asset, amount, AssetState.PORT);
        emit SentToPosition(position, asset, amount, parameters);
    }

    function _load(
        address from,
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) internal virtual;

    function _unload(
        address to,
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) internal virtual;

    function _sendToPosition(
        address to,
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        AssetState calldata toState,
        bytes calldata parameters
    ) internal virtual;
}
