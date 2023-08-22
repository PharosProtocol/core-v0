// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {C} from "src/libraries/C.sol";
import {IWETH9} from "src/interfaces/external/IWETH9.sol";
// import {IFreighter} from "src/interfaces/IFreighter.sol";
import {Asset, AssetState} from "src/libraries/LibUtils.sol";

// Supports:
// Rebasing tokens
//
// Not Supported:
// Fee on transfer tokens

/// @notice Freight for moving ERC20 tokens.
/// @dev adheres to IFreighter interface.
library ERC20Freighter {
    function balance(Asset calldata asset, AssetState calldata, bytes calldata) external view returns (uint256) {
        return IERC20(asset.addr).balanceOf(address(this));
    }

    /// @dev user eoa must approve erc20 transfer before calling this.
    function pull(
        address from,
        Asset calldata asset,
        uint256 amount,
        AssetState calldata,
        bytes calldata
    ) external payable {
        _safeErc20TransferFrom(asset.addr, from, address(this), amount);
    }

    /// @dev user eoa must approve erc20 transfer before calling this.
    function push(address to, Asset calldata asset, uint256 amount, AssetState calldata, bytes calldata) external {
        _safeErc20Transfer(asset.addr, to, amount);
    }

    // NOTE security how is correctness of amount ensured? bk?
    function processReceipt(
        Asset calldata asset,
        uint256 amount,
        AssetState calldata fromState,
        AssetState calldata,
        bytes calldata
    ) external {
        if (fromState == AssetState.USER && msg.value == amount && asset.addr == C.WETH) {
            IWETH9(C.WETH).deposit{value: msg.value}();
        }
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
