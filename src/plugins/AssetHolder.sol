// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {IAssetHolder} from "src/interfaces/IAssetHolder.sol";
import {IFreighter} from "src/interfaces/IFreighter.sol";
import {Asset, AssetState, PluginRef} from "src/libraries/LibUtils.sol";
import {C} from "src/libraries/C.sol";

/// @notice this very verbose abstract contract exists to allow for the use of the freighter logic in the state
///         space of Ports and Terminals. Every function is a wrapper for a freighter library function.
abstract contract AssetHolder is AccessControl, CloneFactory {
    constructor(address handlerAddr, address bookkeeperAddr) CloneFactory(bookkeeperAddr) {}

    function balance(
        PluginRef calldata freighter,
        Asset calldata asset,
        AssetState calldata state
    ) public view proxyExecution returns (uint256) {
        IFreighter(freighter.addr).balance(asset, state, freighter.parameters);
    }

    function pull(
        address from,
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        AssetState calldata toState
    ) external payable proxyExecution onlyRole(C.CONTROLLER_ROLE) {
        IFreighter(freighter.addr).pull(from, asset, amount, toState, freighter.parameters);
    }

    function push(
        address to,
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        AssetState calldata fromState
    ) external proxyExecution onlyRole(C.CONTROLLER_ROLE) {
        IFreighter(freighter.addr).push(to, asset, amount, fromState, freighter.parameters);
    }

    function processReceipt(
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        AssetState calldata fromState,
        AssetState calldata toState
    ) external proxyExecution onlyRole(C.CONTROLLER_ROLE) {
        IFreighter(freighter.addr).processReceipt(asset, amount, fromState, toState, freighter.parameters);
        // _processReceipt(freighter, asset, amount, state);
    }

    // function _processReceipt(
    //     PluginRef calldata freighter,
    //     Asset calldata asset,
    //     uint256 amount,
    //     AssetState calldata fromState,
    //     AssetState calldata toState
    // ) internal proxyExecution {
    //     IFreighter(freighter.addr).receiptCallback(asset, amount, state, freighter.parameters);
    // }
}
