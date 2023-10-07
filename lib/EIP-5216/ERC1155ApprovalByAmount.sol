// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./IERC1155ApprovalByAmount.sol";

/**
 * @dev Extension of {ERC1155} that allows you to approve your tokens by amount and id.
 */
abstract contract ERC1155ApprovalByAmount is ERC1155, IERC1155ApprovalByAmount {

    // Mapping from account to operator approvals by id and amount.
    mapping(address => mapping(address => mapping(uint256 => uint256))) internal _allowances;

    /**
     * @dev See {IERC1155ApprovalByAmount}
     */
    function approve(address operator, uint256 id, uint256 amount) public virtual {
        _approve(_msgSender(), operator, id, amount);
    }

    /**
     * @dev See {IERC1155ApprovalByAmount}
     */
    function allowance(address account, address operator, uint256 id) public view virtual returns (uint256) {
        return _allowances[account][operator][id];
    }

    /**
     * @dev safeTransferFrom implementation for using ApprovalByAmount extension
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override(IERC1155, ERC1155) {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()) || allowance(from, _msgSender(), id) >= amount,
            "ERC1155: caller is not owner nor approved nor approved for amount"
        );
        if(from != _msgSender() && !isApprovedForAll(from, _msgSender())) {
            unchecked {
                _allowances[from][_msgSender()][id] -= amount;
            }
        }
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev safeBatchTransferFrom implementation for using ApprovalByAmount extension
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override(IERC1155, ERC1155) {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()) || _checkApprovalForBatch(from, _msgSender(), ids, amounts),
            "ERC1155: transfer caller is not owner nor approved nor approved for some amount"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Checks if all ids and amounts are permissioned for `to`. 
     *
     * Requirements:
     * - `ids` and `amounts` length should be equal.
     */
    function _checkApprovalForBatch(
        address from, 
        address to, 
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual returns (bool) {
        uint256 idsLength = ids.length;
        uint256 amountsLength = amounts.length;

        require(idsLength == amountsLength, "ERC1155ApprovalByAmount: ids and amounts length mismatch");
        for (uint256 i = 0; i < idsLength;) {
            if(_allowances[from][to][ids[i]] < amounts[i]) {
                return false;
            }
            unchecked { 
                _allowances[from][to][ids[i]] -= amounts[i];
                ++i; 
            }
        }
        return true;
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens by id and amount.
     * Emits a {ApprovalByAmount} event.
     */
    function _approve(
        address owner,
        address operator,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC1155ApprovalByAmount: approve from the zero address");
        require(operator != address(0), "ERC1155ApprovalByAmount: approve to the zero address");
        _allowances[owner][operator][id] = amount;
        emit ApprovalByAmount(owner, operator, id, amount);
    }
}