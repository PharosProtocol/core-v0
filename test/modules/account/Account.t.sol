// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
 * comprehensive as each unique implementation will likely need its own unique tests.
 */

import "forge-std/Test.sol";

import {C} from "src/C.sol";
import {Asset, AssetStandard, ETH_STANDARD} from "src/LibUtil.sol";
import {DoubleSidedAccount} from "src/modules/account/implementations/DoubleSidedAccount.sol";

contract AccountTest is Test {
    DoubleSidedAccount public accounts;
    Asset[] assets;
    uint256[] amounts;

    Asset ethAsset = Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""});

    // Copy of event definitions.
    event AssetAdded(address owner, bytes32 salt, Asset asset, uint256 amount);
    event AssetRemoved(address owner, bytes32 salt, Asset asset, uint256 amount);

    // invoked before each test case is run
    function setUp() public {
        // delete assets;
        // delete amounts;
        vm.recordLogs();
        accounts = new DoubleSidedAccount();
        // accounts = DoubleSidedAccount(address(0));
    }

    function testFuzz_CreateAndAdd(address lender, bytes32 salt, uint256 amount) public {
        vm.assume(lender != address(0));

        DoubleSidedAccount.Parameters memory parameters =
            DoubleSidedAccount.Parameters({owner: lender, ownerAccountSalt: salt});
        bytes memory encodedParameters = abi.encode(parameters);

        // assets.push(ethAsset);
        // amounts.push(amount);
        vm.expectEmit(true, true, true, true);
        emit AssetAdded(lender, salt, ethAsset, amount);

        vm.deal(lender, amount);
        vm.startPrank(lender);
        accounts.addAssetFrom{value: amount}(lender, ethAsset, amount, encodedParameters);

        assertEq(accounts.getOwner(encodedParameters), lender);
        assertEq(accounts.getBalance(ethAsset, encodedParameters), amount);
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
}
