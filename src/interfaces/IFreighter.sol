// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Asset, PluginRef} from "src/libraries/LibUtils.sol";

interface IFreighter {
    function pullToPort(Asset calldata asset, uint256 amount, address from, bytes calldata parameters) external;

    function pullToTerminal(Asset calldata asset, uint256 amount, address from, bytes calldata parameters) external;

    function pushFromPort(Asset calldata asset, uint256 amount, address to, bytes calldata parameters) external;

    function pushFromTerminal(Asset calldata asset, uint256 amount, address to, bytes calldata parameters) external;

    function portReceiptCallback(Asset calldata asset, uint256 amount, bytes calldata parameters) external;

    function terminalReceiptCallback(Asset calldata asset, uint256 amount, bytes calldata parameters) external;
}
