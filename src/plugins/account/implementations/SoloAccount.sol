// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {C} from "src/libraries/C.sol";
import {Account} from "../Account.sol";
import {IWETH9} from "src/interfaces/external/IWETH9.sol";
import {IFreighter} from "src/interfaces/IFreighter.sol";
import {Asset, ERC20_STANDARD, LibUtils, PluginRef} from "src/libraries/LibUtils.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";

/// @notice Account for a single user to hold arbitrary assets used in p2p agreements.
/// @dev this is a very simple example of an account.
contract SoloAccount is Account {
    // struct Parameters {}

    constructor(address bookkeeperAddr) Account(bookkeeperAddr) {}

    /// @notice Set owner.
    function _initialize(bytes calldata initData) internal override {
        owner = abi.decode(initData, (address));
    }

    function _load(address, PluginRef calldata, Asset calldata, uint256, bytes calldata) internal override {}

    function _unload(address, PluginRef calldata, Asset calldata, uint256, bytes calldata) internal override {
        require(msg.sender == owner, "only owner can unload");
    }

    function _sendToPosition(
        address,
        PluginRef calldata,
        Asset calldata,
        uint256,
        AssetState calldata,
        bytes calldata
    ) internal override {}
}
