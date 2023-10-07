// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/*
 * This util functions are public so that they can be called from decoded calldata. Specifically this pattern
 * is used with position passthrough functions.
 */

library LibUtilsPublic {
    /// @notice send eth to address.
    /// @dev vulnerable to reentrancy. ensure reentrancy safety in calling function.
    function ethCallTransfer(address payable to, uint256 amount) public {
        (bool success, ) = to.call{value: amount}("");
        require(success, "ethCallTransfer failed");
    }

    // SECURITY NOTE: did not account for fee on transfer ERC20s. Either need to update logic or restrict to
    //                non-fee ERC20s.

    /// @notice Transfers tokens from msg.sender to a recipient.
    function safeErc20Transfer(address token, address to, uint256 amount) public {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "safeErc20Transfer failed");
    }

    /// @notice Transfers tokens from the targeted address to the given destination.
    function safeErc20TransferFrom(address token, address from, address to, uint256 amount) public {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "safeErc20TransferFrom failed");
    }

    /// @notice Transfers a specific ERC-721 token from one address to another.
    function safeErc721TransferFrom(
        address token,
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public {
        IERC721(token).safeTransferFrom(from, to, tokenId, data);
    }

    /// @notice Transfers a specific ERC-1155 token from one address to another.
    function safeErc1155TransferFrom(
        address token,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public {
        IERC1155(token).safeTransferFrom(from, to, id, amount, data);
    }

}
