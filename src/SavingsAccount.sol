// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "src/Storage.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * Crates represent a provision of supply. For each supplier and asset combination
 * there exists exactly 1 crate.
 */
struct Crate {
    address supplier;
    address asset;
    uint256 amount;
    uint32 allowedInstructionSet;
}
// uint32[] allowedInstructionSets;

/**
 * The Savings Account is a pool of all allowed assets where suppliers can add or remove supply and
 * assign that supply to certain Instruction Sets. The Savings account is the layer between suppliers
 * and the Instruction sets.
 * 
 * - A Crate of supply can only be assigned to 1 Instruction Set.
 * - A user can provide multiple Crates with different configurations.
 */
contract SavingsAccount {
    mapping(address => bool) allowedAssets;
    // All supplier+asset crates. Will grow O(N).
    mapping(address => mapping(address => Crate)) crates;
    // Total amount of asset supplied to an Instruction set.
    // mapping(address => mapping(uint32 => uint256)) suppliedAmounts;
    mapping(uint32 => uint256) suppliedAmounts;
    // Total amount of asset borrowed by an Instruction set.
    // mapping(address => mapping(uint32 => uint256)) borrowedAmounts;
    mapping(uint32 => uint256) borrowedAmounts;

    // Suppliers -> Savings Account.
    function addSupply(address asset, uint256 amount) public payable {
        // Create or update Crate.
        Crate memory crate = crates[msg.sender][asset];
        if (crate.supplier == address(0x0)) {
            crate.supplier = msg.sender;
            crate.asset = asset;
            crate.amount = amount;
        } else {
            crate.amount = crate.amount + amount;
        }
        // If using Eth.
        if (asset == address(0x0)) {
            require(msg.value == amount); // what happens if someone puts eth into the contract directly?
        } // Else if using an ERC20.
        else {
            require(IERC20(asset).transfer(address(this), amount));
        }
        _incrementSuppliedAmount(crate.allowedInstructionSet, amount);
    }

    function removeSupply(address asset, uint256 amount) public {
        Crate memory crate = crates[msg.sender][asset];
        crate.amount -= amount; // Protected by Sol 0.8 overflow reverts.
        // If using Eth.
        if (asset == address(0x0)) {
            payable(msg.sender).transfer(amount);
        } // Else if using an ERC20.
        else {
            require(IERC20(asset).transfer(address(this), amount));
        }
        _decrementSuppliedAmount(crate.allowedInstructionSet, amount);
    }

    function setAssetAllowedInstructionSet(address asset, uint32 instructionSet) public {
        Crate memory crate = crates[msg.sender][asset];
        require(crate.supplier != address(0x0));
        // What are the profit implications of migrating a suppliers position?
        _decrementSuppliedAmount(crate.allowedInstructionSet, crate.amount);
        _incrementSuppliedAmount(instructionSet, crate.amount);
    }

    // Instruction Sets -> Savings Account.
    function borrowSupply(uint32 instructionSet, uint256 amount) internal {
        _decrementBorrowedAmount(instructionSet, amount);
    }

    function returnSupply(uint32 instructionSet, uint256 amount) internal {
        _incrementBorrowedAmount(instructionSet, amount);
    }

    // Public Helpers.
    function getSuppliedAmount(uint32 instructionSet) public view returns (uint256) {
        return suppliedAmounts[instructionSet];
    }

    function getBorrowedAmount(uint32 instructionSet) public view returns (uint256) {
        return borrowedAmounts[instructionSet];
    }

    function getAvailableAmount(uint32 instructionSet) public view returns (uint256) {
        return suppliedAmounts[instructionSet] - borrowedAmounts[instructionSet];
    }

    function getUtilizationRatio(uint32 instructionSet) public view returns (uint256) {
        return borrowedAmounts[instructionSet] / suppliedAmounts[instructionSet];
    }

    // Private Helpers.

    // What are the profit implications when changing a suppliers position?
    function _incrementSuppliedAmount(uint32 instructionSet, uint256 amount) private {
        if (instructionSet == 0x0) {
            return;
        }
        suppliedAmounts[instructionSet] += amount;
        emit InstructionSetSupplyIncreased(instructionSet, amount);
    }

    // What are the profit implications when changing a suppliers position?
    function _decrementSuppliedAmount(uint32 instructionSet, uint256 amount) private {
        if (instructionSet == 0x0) {
            return;
        }
        suppliedAmounts[instructionSet] -= amount;
        emit InstructionSetSupplyDecreased(instructionSet, amount);
    }

    function _decrementBorrowedAmount(uint32 instructionSet, uint256 amount) private {
        if (instructionSet == 0x0) {
            return;
        }
        borrowedAmounts[instructionSet] -= amount;
        emit InstructionSetBorrowDecreased(instructionSet, amount);
    }

    function _incrementBorrowedAmount(uint32 instructionSet, uint256 amount) private {
        if (instructionSet == 0x0) {
            return;
        }
        borrowedAmounts[instructionSet] += amount;
        emit InstructionSetBorrowIncreased(instructionSet, amount);
    }

    // Events.
    event InstructionSetSupplyIncreased(uint32 instructionSet, uint256 amount);
    event InstructionSetSupplyDecreased(uint32 instructionSet, uint256 amount);
    event InstructionSetBorrowIncreased(uint32 instructionSet, uint256 amount);
    event InstructionSetBorrowDecreased(uint32 instructionSet, uint256 amount);
}
