// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "src/C.sol";
import "src/Storage.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * Crates represent a provision of supply. For each supplier and asset combination
 * there exists exactly 1 crate.
 */
struct Crate {
    address supplier;
    address asset;
    // uint256 amount;
    uint256 ownership; // arbitrary number representing % share of term sheet supply.
    uint32 instructions;
}
// uint32[] Instructionss;

/**
 * The Savings Account is a pool of all allowed assets where suppliers can add or remove supply and
 * assign that supply to certain Term Sheets. The Savings account is the layer between suppliers
 * and the term sheets.
 *
 * - A Crate of supply can only be assigned to 1 Term Sheet.
 * - A user can provide multiple Crates with different configurations.
 */
contract SavingsAccount {
    mapping(address => bool) private allowedAssets;
    // All supplier+asset crates. Will grow O(N).
    mapping(address => mapping(address => Crate)) private crates;
    // Total amount of asset supplied to a term sheet.
    mapping(uint32 => uint256) private suppliedAmounts; // e.g. Realized value
    // Total amount of ownership in a term sheet.
    mapping(uint32 => uint256) private ownershipAmounts;
    // Total amount of asset borrowed by a term sheet.
    mapping(uint32 => uint256) private borrowedAmounts;

    // Suppliers -> Savings Account.
    function addSupply(address asset, uint256 amount) public payable {
        // If using Eth.
        if (asset == address(0)) {
            require(msg.value == amount); // what happens if someone puts eth into the contract directly?
        } // Else if using an ERC20.
        else {
            require(IERC20(asset).transfer(address(this), amount));
        }
        RealizeProfits(crates[msg.sender][asset].instructions);
        AddToOrInitCrate(msg.sender, asset, amount);
    }

    //Q Reentrancy vulnerabilities here?
    function removeSupply(address asset, uint256 amount, bool realizeProfits) public {
        // If using Eth.
        if (asset == address(0)) {
            payable(msg.sender).transfer(amount);
        } // Else if using an ERC20.
        else {
            require(IERC20(asset).transferFrom(address(this), msg.sender, amount));
        }
        if (realizeProfits) {
            RealizeProfits(crates[msg.sender][asset].instructions);
        }
        RemoveFromCrate(msg.sender, asset, amount);
    }

    function setCrateInstructions(address asset, uint32 instructions, bool realizeProfits) public {
        if (realizeProfits) {
            RealizeProfits(crates[msg.sender][asset].instructions);
        }
        uint256 amount = EmptyCrate(msg.sender, asset); //Q will it use less gas to not use a local variable here?
        RealizeProfits(instructions);
        AddToOrInitCrate(msg.sender, asset, amount);
    }

    function borrowFromSupply(uint32 instructions, uint256 amount) internal {
        if (instructions == 0x0) {
            return;
        }
        borrowedAmounts[instructions] += amount;
        require(borrowedAmounts[instructions] <= suppliedAmounts[instructions])
        emit InstructionsBorrowIncreased(instructions, amount);
    }

    // Term Sheets -> Savings Account.
    function returnSupply(uint32 instructions, uint256 amount) internal {
        if (instructions == 0x0) {
            return;
        }
        borrowedAmounts[instructions] -= amount;
        emit InstructionsBorrowDecreased(instructions, amount);
    }

    // Increasing supplied amount without changing ownership will distribute profits.
    function RewardToSupply(uint32 instructions, uint256 amount) internal {
        suppliedAmounts[instructions] += amount;
    }

    // Public Helpers.
    function getSuppliedAmount(uint32 instructions) public view returns (uint256) {
        return suppliedAmounts[instructions];
    }

    function getOwnershipAmount(uint32 instructions) public view returns (uint256) {
        return ownershipAmounts[instructions];
    }

    function getBorrowedAmount(uint32 instructions) public view returns (uint256) {
        return borrowedAmounts[instructions];
    }

    function getAvailableAmount(uint32 instructions) public view returns (uint256) {
        return suppliedAmounts[instructions] - borrowedAmounts[instructions];
    }

    function getUtilizationRatio(uint32 instructions) public view returns (uint256) {
        return borrowedAmounts[instructions] / suppliedAmounts[instructions];
    }

    // Private Helpers.
    // Use asset==0x0 for Eth.
    function AddToOrInitCrate(address supplier, address asset, uint256 amount) internal returns (Crate storage crate) {
        crate = crates[supplier][asset];
        if (crate.supplier == address(0x0)) {
            crate.supplier = supplier;
            crate.asset = asset;
            // crate.instructions = 0; // Assigned to the null instructions.
        }
        uint256 ownership;
        // If Instructions empty, init to arbitrary base value.
        if (ownershipAmounts[crate.instructions] == 0) ownership = C.OWNERSHIP_BASE;
        else ownership = amount / suppliedAmounts[crate.instructions] * ownershipAmounts[crate.instructions];
        suppliedAmounts[crate.instructions] += amount;
        ownershipAmounts[crate.instructions] += amount;
        crate.ownership += ownership;
        InstructionsSupplyIncreased(crate.instructions, amount);
    }

    // Use asset==0x0 for Eth.
    function RemoveFromCrate(address supplier, address asset, uint256 amount) internal returns (Crate storage crate) {
        crate = crates[supplier][asset];
        uint256 ownership = amount / suppliedAmounts[crate.instructions] * ownershipAmounts[crate.instructions];
        suppliedAmounts[crate.instructions] -= amount;
        ownershipAmounts[crate.instructions] -= ownership;
        crate.ownership -= ownership;
        InstructionsSupplyDecreased(crate.instructions, amount);
    }

    function EmptyCrate(address supplier, address asset) internal returns (uint256 amount) {
        Crate storage crate = crates[supplier][asset]; //Q using storage is less guess, since it already is there?
        amount = crate.ownership / ownershipAmounts[crate.instructions] * suppliedAmounts[crate.instructions];
        RemoveFromCrate(supplier, asset, amount);
    }

    // Process all unrealized Lender profits for a term sheet.
    // Although the ownership system accounts for distribution of value after underlying changes
    // in assets, it cannot account for unknown profit. Although some profit can be estimated 
    // profit share cannot, thus this must  be called before entering/exiting or else
    // unrealized profits will be unfairly distributed.
    function RealizeProfits(uint32 instructions) private {
        if (instructions == 0) {return;}
        // Instructions i = new Instructions(instructions); // How to get the right instance? Factory?
        // i.exitProfits();
    }

    // Events.
    event InstructionsSupplyIncreased(uint32 instructions, uint256 amount);
    event InstructionsSupplyDecreased(uint32 instructions, uint256 amount);
    event InstructionsBorrowIncreased(uint32 instructions, uint256 amount);
    event InstructionsBorrowDecreased(uint32 instructions, uint256 amount);
}
