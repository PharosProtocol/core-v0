// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "forge-std/Test.sol";

import {SupplyAccount, SupplyAccountRegistry} from "src/modulus/SupplyAccount.sol";

contract SupplyAccountTest is Test {
    SupplyAccountRegistry public supplyAccountRegistry;
    // uint8 public numAssets = 4;
    address[] assets;
    uint256[] amounts;
    uint256 constant maxAssets = 4;

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        supplyAccountRegistry = new SupplyAccountRegistry();

        // bytes32[] ids;
    }

    function test_createEmptySupplyAccount(address supplier, bytes32 _id) public {
        vm.startPrank(supplier);
        supplyAccountRegistry.createSupplyAccount(_id, new bytes32[](0), new address[](0), new uint256[](0));
        assertGt(supplyAccountRegistry.supplyAccountCount(), 0);
    }

    // function createSupplyAccount(bytes32 _id, address[] calldata _assets, uint256[] calldata _amounts) public {
    //     // Limit size of assets, for sanity.
    //     if (_amounts.length < maxAssets && _amounts.length < _assets.length) {
    //         return;
    //     }
    //     if (_assets.length > maxAssets) {
    //         assets = _assets[:maxAssets];
    //         amounts = _amounts[:maxAssets];
    //     }
    //     supplyAccountRegistry.createSupplyAccount(_id, new bytes32[](0), assets, amounts);
    // }

    // function test_OwnerIncrementAsNotOwner(address sender) public {
    //     vm.assume(sender != counter.owner());
    //     vm.expectRevert();
    //     vm.prank(sender);
    //     // console.log('owner:');
    //     // address a = counter.owner();
    //     // console.log("address: %s", a);
    //     counter.ownerIncrement();
    // }

    // function invariant_supplyAmountsPositive() public {
    //     Vm.Log[] memory entries = vm.getRecordedLogs();
    //     // bytes32[entries.length] memory supplyAccountIds;

    //     // Find all existing supply account IDs.
    //     for (uint256 i; i < entries.length; i++) {
    //         if (entries[i].topics[0] == keccak256("SupplyAccountCreated(address, bytes32)")) {
    //             for (uint256 j; j < assets.length; j++) {
    //                 assertGe(supplyAccountRegistry.getAccountAssetAmount(entries[i].topics[3], assets[j]), 0);
    //             }
    //             // supplyAccountIds.push(entries[i].topics[3]);
    //         }
    //     }
    // }
}
