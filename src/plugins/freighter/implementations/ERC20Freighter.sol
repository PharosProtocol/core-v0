// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {IFreighter} from "src/interfaces/IFreighter.sol";
import {Asset} from "src/libraries/LibUtils.sol";

/// @notice Freight for moving ERC20 tokens.
/// @dev adheres to IFreighter interface.
library ERC20Freighter {
    /// @dev user eoa must approve erc20 transfer before calling this.
    function pullToPort(Asset calldata asset, uint256 amount, address from, bytes calldata) external  {
        _safeErc20TransferFrom(asset.addr, from, address(this), amount);
    }

    /// @dev user eoa must approve erc20 transfer before calling this.
    function pullToTerminal(Asset calldata asset, uint256 amount, address from, bytes calldata) external  {
        _safeErc20TransferFrom(asset.addr, from, address(this), amount);
    }

    function pushFromPort(Asset calldata asset, uint256 amount, address to, bytes calldata) external  {
        _safeErc20Transfer(asset.addr, to, amount);
    }

    function pushFromTerminal(Asset calldata asset, uint256 amount, address to, bytes calldata) external  {
        _safeErc20Transfer(asset.addr, to, amount);
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
