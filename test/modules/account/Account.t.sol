// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
 * comprehensive as each unique implementation will likely need its own unique tests.
 */

import "forge-std/Test.sol";

import {Asset, AssetStandard, ETH_STANDARD} from "src/LibUtil.sol";
import {C} from "src/C.sol";
import {DoubleSidedAccount, Parameters} from "src/modules/account/implementations/DoubleSidedAccount.sol";

contract OfferAccountTest is Test {
    DoubleSidedAccount public accounts;

    event AssetAdded(bytes32 accountId, Asset asset, uint256 amount);

    // invoked before each test case is run
    function setUp() public {
        // vm.recordLogs();
        accounts = new DoubleSidedAccount();
        // accounts = DoubleSidedAccount(address(0));
    }

    function test_createEmptyAccount() public {
        address lender = address(1000);
        Asset memory asset = Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""});
        Asset[] memory assets = new Asset[](1);
        assets[0] = asset; // seriously solidity - tf even is this syntax
        uint256 amount = 1 * 10 ** C.ETH_DECIMALS;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        Parameters memory parameters = Parameters({owner: lender, ownerAccountSalt: "1234"});
        bytes memory encodedParameters = abi.encode(parameters);
        bytes32 id = keccak256(abi.encodePacked(parameters.owner, parameters.ownerAccountSalt));

        // vm.expectEmit(true, true, true, true);
        // // emit accounts.AssetAdded(id, asset, amount);
        // emit AssetAdded(id, asset, amount);

        vm.deal(lender, amount);
        vm.startPrank(lender);
        accounts.addAssetFrom{value: amount}(lender, asset, amount, encodedParameters);

        assertEq(accounts.getOwner(encodedParameters), lender);
        assertEq(accounts.getBalances(assets, encodedParameters), amounts);
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
