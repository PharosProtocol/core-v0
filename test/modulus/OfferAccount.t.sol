// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "forge-std/Test.sol";

// import {OfferAccount, OfferAccountRegistry} from "src/protocol/OfferAccount.sol";

/*
contract OfferAccountTest is Test {
    OfferAccountRegistry public offerAccountRegistry;
    // uint8 public numAssets = 4;
    address[] assets;
    uint256[] amounts;
    uint256 constant maxAssets = 4;

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        offerAccountRegistry = new OfferAccountRegistry();
    }

    function test_createEmptyOfferAccount(address lender, bytes32 _id) public {
        vm.startPrank(lender);
        offerAccountRegistry.createOfferAccount(_id, new bytes32[](0), new address[](0), new uint256[](0));
        assertEq(offerAccountRegistry.accountCount(), 1);
    }

    // function createOfferAccount(bytes32 _id, address[] calldata _assets, uint256[] calldata _amounts) public {
    //     // Limit size of assets, for sanity.
    //     if (_amounts.length < maxAssets && _amounts.length < _assets.length) {
    //         return;
    //     }
    //     if (_assets.length > maxAssets) {
    //         assets = _assets[:maxAssets];
    //         amounts = _amounts[:maxAssets];
    //     }
    //     offerAccountRegistry.createOfferAccount(_id, new bytes32[](0), assets, amounts);
    // }

    // function invariant_offerAmountsPositive() public {
    //     Vm.Log[] memory entries = vm.getRecordedLogs();
    //     // bytes32[entries.length] memory offerAccountIds;

    //     // Find all existing offer account IDs.
    //     for (uint256 i; i < entries.length; i++) {
    //         if (entries[i].topics[0] == keccak256("OfferAccountCreated(address, bytes32)")) {
    //             for (uint256 j; j < assets.length; j++) {
    //                 assertGe(offerAccountRegistry.getAccountAssetAmount(entries[i].topics[3], assets[j]), 0);
    //             }
    //             // offerAccountIds.push(entries[i].topics[3]);
    //         }
    //     }
    // }
}*/
