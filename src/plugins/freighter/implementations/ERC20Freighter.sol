// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {C} from "src/libraries/C.sol";
import {IWETH9} from "src/interfaces/external/IWETH9.sol";
// import {IFreighter} from "src/interfaces/IFreighter.sol";
import {AddrCategory, Asset} from "src/libraries/LibUtils.sol";

// NOTE need to implement support for inline ETH wrapping

// Supports:
// Rebasing tokens
//
// Not Supported:
// Fee on transfer tokens

/// @notice Freight for moving ERC20 tokens.
/// @dev adheres to IFreighter interface.
library ERC20Freighter {
    /// @dev user eoa must approve erc20 transfer before calling this.
    function pullToPort(address from, Asset calldata asset, uint256 amount, bytes calldata) external payable {
        _safeErc20TransferFrom(asset.addr, from, address(this), amount);
    }

    /// @dev user eoa must approve erc20 transfer before calling this.
    function pullToTerminal(address from, Asset calldata asset, uint256 amount, bytes calldata) external payable {
        _safeErc20TransferFrom(asset.addr, from, address(this), amount);
    }

    function pushFromPort(address to, Asset calldata asset, uint256 amount, bytes calldata) external {
        _safeErc20Transfer(asset.addr, to, amount);
    }

    function pushFromTerminal(address to, Asset calldata asset, uint256 amount, bytes calldata) external {
        _safeErc20Transfer(asset.addr, to, amount);
    }

    // NOTE security how is correctness of amount ensured? bk?
    function portReceiptCallback(Asset calldata asset, uint256 amount, bytes calldata) external {
        // Allows for 1 txn deposit of eth to use as weth.
        if (msg.value == amount && asset.addr == C.WETH) {
            IWETH9(C.WETH).deposit{value: msg.value}();
        }
    }

    function termReceiptCallback(Asset calldata asset, uint256 amount, bool, bytes calldata) external {}

    function getBalance(address addr, Asset calldata asset, AddrCategory, bytes calldata) external view {
        return IERC20(asset.addr).balanceOf(addr);
    }

    // SECURITY NOTE: did not account for fee on transfer ERC20s. Either need to update logic or restrict to
    //                non-fee ERC20s.

    /// @notice Transfers tokens from msg.sender to a recipient.
    function _safeErc20Transfer(address token, address to, uint256 amount) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "safeErc20Transfer failed");
    }

    /// @notice Transfers tokens from the targeted address to the given destination.
    function _safeErc20TransferFrom(address token, address from, address to, uint256 amount) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "safeErc20TransferFrom failed");
    }
}
