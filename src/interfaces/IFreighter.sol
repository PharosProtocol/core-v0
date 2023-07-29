// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AddrCategory, Asset, PluginRef} from "src/libraries/LibUtils.sol";

// A freighter represents a state machine with 3 states: external, port, terminal. At each of these states the asset
// being managed should always be in only 1 form. The forms may be different at different states.

interface IFreighter {
    function pullToPort(address from, Asset calldata asset, uint256 amount, bytes calldata parameters) external payable;

    function pullToTerminal(
        address from,
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external payable;

    function pushFromPort(address to, Asset calldata asset, uint256 amount, bytes calldata parameters) external;

    function pushFromTerminal(address to, Asset calldata asset, uint256 amount, bytes calldata parameters) external;

    function portReceiptCallback(Asset calldata asset, uint256 amount, bytes calldata parameters) external;

    function termReceiptCallback(Asset calldata asset, uint256 amount, bool isColl, bytes calldata parameters) external;

    /// @dev balance should not be assumed to be static. It could change unexpectedly and should be recalculated.
    function getBalance(
        address addr,
        Asset calldata asset,
        AddrCategory category,
        bytes calldata parameters
    ) external view;
}
