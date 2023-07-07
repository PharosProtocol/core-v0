// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
 * This util functions are public so that they can be called from decoded calldata. Specifically this pattern
 * is used with position passthrough functions. 
 */

library LibUtilsPublic {
    // SECURITY NOTE: did not account for fee on transfer ERC20s. Either need to update logic or restrict to non-fee ERC20s.
    //                Probably easiest to do the later and treat fee-based erc20s as a different asset type.

    /// @notice Transfers tokens from msg.sender to a recipient.
    /// @dev Return value is optional.
    function safeErc20Transfer(address token, address to, uint256 value) public {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "UtilsPublic.safeErc20Transfer failed");
    }

    /// @notice Transfers tokens from the targeted address to the given destination.
    /// @dev Return value is optional.
    function safeErc20TransferFrom(address token, address from, address to, uint256 value) public {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "UtilsPublic.safeErc20TransferFrom failed");
    }
}
