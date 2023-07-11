// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/*

//  * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
//  * comprehensive as each unique implementation will likely need its own unique tests.
 

// INVARIANT user marks <= marks
// INVARIANT user contributions <= contributions

import "forge-std/Test.sol";
import {HandlerUtils, TestUtils} from "test/TestUtils.sol";

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {C} from "src/libraries/C.sol";
import {Asset, ETH_STANDARD, ERC20_STANDARD} from "src/libraries/LibUtils.sol";
import {Order} from "src/libraries/LibBookkeeper.sol";
import {PoolSupplyAccount} from "src/modules/account/implementations/PoolSupplyAccount.sol";

contract PoolSupplyAccountTest is TestUtils {
    PoolSupplyAccount public accountModule;
    Asset[] ASSETS;
    address bookkeeperAddr;
    address positionAddr;

    // Copy of events definitions.
    event LoadedFromUser(Asset asset, uint256 amount, bytes parameters);
    event LoadedFromPosition(Asset asset, uint256 amount, bytes parameters);
    event UnloadedToUser(Asset asset, uint256 amount, bytes parameters);
    event UnloadedToPosition(address position, Asset asset, uint256 amount, bool isLockedColl, bytes parameters);
    event LockedCollateral(Asset asset, uint256 amount, bytes parameters);
    event UnlockedCollateral(Asset asset, uint256 amount, bytes parameters);

    constructor() {
        // ASSETS.push(Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""})); // Tests expect 0 index to be ETH
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.WETH, decimals: 18, id: 0, data: ""})); // Tests expect 0 index to be WETH
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.USDC, decimals: C.USDC_DECIMALS, id: 0, data: ""})); // Tests expect 1 index to be an ERC20
    }

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl("mainnet"), 17092863);
        Order[] memory orders;
        bookkeeperAddr = address(99999);
        accountModule = new PoolSupplyAccount(bookkeeperAddr, orders);
        positionAddr = address(1);
    }

    // NOTE it is unclear if this should be a fuzz or a direct unit tests. Are fuzzes handled by invariant tests?
    function test_UserCallsPool() public {
        vm.assume(msg.sender != address(0));

        address user0 = address(100);
        address user1 = address(101);

        // Deal 10e18 of each asset.
        for (uint256 i; i < ASSETS.length; i++) {
            dealErc20(ASSETS[i].addr, user0, 10e18);
            dealErc20(ASSETS[i].addr, user1, 10e18);
            dealErc20(ASSETS[i].addr, positionAddr, 10e18);
        }

        // Define account instance.
        bytes memory parameters0 = abi.encode(PoolSupplyAccount.Parameters({user: user0}));
        assertEq(accountModule.getOwner(parameters0), address(accountModule), "invalid owner");

        // Fail to unload WETH because account module is fully empty.
        vm.prank(user0);
        vm.expectRevert("_unloadToUser: asset minSupply == 0");
        accountModule.unloadToUser(ASSETS[0], 1, parameters0);

        // Fail to add WETH because asset not approved.
        vm.prank(user0);
        vm.expectRevert("UtilsPublic.safeErc20TransferFrom failed");
        accountModule.loadFromUser(ASSETS[0], 5e18, parameters0);

        // Fail to add ERC20 because asset not approved.
        vm.prank(user0);
        vm.expectRevert("UtilsPublic.safeErc20TransferFrom failed");
        accountModule.loadFromUser(ASSETS[1], 5e18, parameters0);

        // Approve ERC20s.
        vm.prank(user0);
        IERC20(ASSETS[0].addr).approve(address(accountModule), 999e18);
        vm.prank(user0);
        IERC20(ASSETS[1].addr).approve(address(accountModule), 999e18);

        // Fail to add ERC20 because balance too low.
        vm.prank(user0);
        vm.expectRevert("UtilsPublic.safeErc20TransferFrom failed");
        accountModule.loadFromUser(ASSETS[0], 11e18, parameters0);

        // Load WETH.
        vm.prank(user0);
        accountModule.loadFromUser{value: 0}(ASSETS[0], 4e18, parameters0);
        assertEq(accountModule.getBalance(ASSETS[0], parameters0), 4e18, "incorrect WETH balance 0");

        // Load ERC20.
        vm.prank(user0);
        accountModule.loadFromUser{value: 0}(ASSETS[1], 4e18, parameters0);
        assertEq(accountModule.getBalance(ASSETS[1], parameters0), 4e18, "incorrect USDC balance 0");

        // Marks will remain 0 until block/time passes.
        vm.warp(block.timestamp + 13);
        vm.roll(block.number + 1);

        // Check WETH balance.
        assertEq(accountModule.getBalance(ASSETS[0], parameters0), 4e18, "incorrect WETH balance 0.1");

        // Check ERC20 balance.
        assertEq(accountModule.getBalance(ASSETS[1], parameters0), 4e18, "incorrect USDC balance 0.1");

        // Unload loan asset to fake position.
        vm.prank(bookkeeperAddr);
        accountModule.unloadToPosition(positionAddr, ASSETS[0], 4e18, false, parameters0);
        assertEq(accountModule.getBalance(ASSETS[0], parameters0), 2e18, "incorrect WETH balance 1");
        assertEq(accountModule.getBalance(ASSETS[1], parameters0), 4e18, "incorrect USDC balance 1");

        // Revert on unload loan asset to fake position.
        vm.prank(bookkeeperAddr);
        vm.expectRevert("_unloadToPosition: amount greater than available");
        accountModule.unloadToPosition(positionAddr, ASSETS[0], 4e18, false, parameters0);

        // Should not change anything.
        vm.warp(block.timestamp + 13);
        vm.roll(block.number + 1);

        // Revert on unload loan asset to fake position.
        vm.prank(bookkeeperAddr);
        vm.expectRevert("_unloadToPosition: amount greater than available");
        accountModule.unloadToPosition(positionAddr, ASSETS[0], 4e18, false, parameters0);

        // Load from fake position.
        vm.prank(positionAddr);
        IERC20(ASSETS[0].addr).approve(address(accountModule), 999e18);
        vm.prank(positionAddr);
        accountModule.loadFromPosition(ASSETS[0], 4e18, parameters0);
        assertEq(accountModule.getBalance(ASSETS[0], parameters0), 4e18, "incorrect WETH balance 2");
        assertEq(accountModule.getBalance(ASSETS[1], parameters0), 4e18, "incorrect USDC balance 2");

        // Should not change anything.
        vm.warp(block.timestamp + 13);
        vm.roll(block.number + 1);

        // Fail to lock collateral. Not compatible.
        vm.prank(bookkeeperAddr);
        vm.expectRevert("PoolAccount: Not compatible with borrowing");
        accountModule.lockCollateral(ASSETS[1], 1e18, parameters0);

        // Fail to unlock collateral. Not compatible.
        vm.prank(bookkeeperAddr);
        vm.expectRevert("PoolAccount: Not compatible with borrowing");
        accountModule.unlockCollateral(ASSETS[1], 1e18, parameters0);

        // Fail to unload locked coll asset to fake position.
        vm.prank(bookkeeperAddr);
        vm.expectRevert("PoolAccount: Not compatible with borrowing");
        accountModule.unloadToPosition(address(1), ASSETS[1], 1e18, true, parameters0);

        // Remove WETH.
        vm.prank(user0);
        accountModule.unloadToUser(ASSETS[0], 4e18, parameters0);
        assertEq(accountModule.getBalance(ASSETS[0], parameters0), 0e18, "incorrect WETH balance 3");

        // Revert because account empty.
        vm.prank(user0);
        // vm.expectRevert("_unloadToUser: withdrawing above user amount");
        vm.expectRevert();
        accountModule.unloadToUser(ASSETS[0], 1, parameters0);

        // Should not change anything.
        vm.warp(block.timestamp + 13);
        vm.roll(block.number + 1);

        // Revert because account empty.
        vm.prank(user0);
        // vm.expectRevert("_unloadToUser: withdrawing above user amount");
        vm.expectRevert();
        accountModule.unloadToUser(ASSETS[0], 1, parameters0);

        // Remove ERC20.
        vm.prank(user0);
        accountModule.unloadToUser(ASSETS[1], 4e18, parameters0);
        assertEq(accountModule.getBalance(ASSETS[1], parameters0), 0e18, "incorrect USDC balance 3");

        // Should not change anything.
        vm.warp(block.timestamp + 13);
        vm.roll(block.number + 1);

        // Revert because account empty.
        vm.prank(user0);
        // vm.expectRevert("_unloadToUser: withdrawing above user amount");
        vm.expectRevert();
        accountModule.unloadToUser(ASSETS[1], 1, parameters0);

        // Revert because non-owned account.
        vm.prank(user1); // non user address
        vm.expectRevert("unload: not owner");
        accountModule.unloadToUser(ASSETS[0], 1, parameters0);
    }
}

// contract Handler is Test, HandlerUtils {
//     address public bookkeeperAddr;
//     PoolSupplyAccount public accountModule;
//     mapping(address => mapping(address => uint256)) public userEarningBalance;
//     mapping(address => uint256) public totalEarningBalance;
//     mapping(address => uint256) public totalBalance;

//     constructor() {
//         // assetBalances = new uint256[](assets.length);

//         bookkeeperAddr = address(99999);
//         Order[] memory orders;
//         accountModule = new PoolSupplyAccount(bookkeeperAddr, orders);
//     }

//     function newActor() public createActor countCall("newActor") {}

//     function loadFromUser(uint256 actorIdxSeed, uint256 assetIdxSeed, uint256 amount)
//         external
//         payable
//         useActor(actorIdxSeed)
//         useAsset(assetIdxSeed)
//         countCall("loadFromUser")
//     {
//         vm.assume(currentAsset.standard == ERC20_STANDARD);
//         amount = bound(amount, 0, type(uint128).max);

//         bytes memory parameters = abi.encode(PoolSupplyAccount.Parameters({user: currentActor}));

//         dealAsset(currentAsset, currentActor, amount);
//         vm.prank(currentActor);
//         IERC20(currentAsset.addr).approve(address(accountModule), amount);

//         vm.prank(currentActor);
//         accountModule.loadFromUser(currentAsset, amount, parameters);

//         // Local tracking updates.
//         userEarningBalance[currentActor][currentAsset.addr] += amount;
//         totalEarningBalance[currentAsset.addr] += amount;
//         totalBalance[currentAsset.addr] += amount;
//     }

//     function unloadToUser(uint256 actorIdxSeed, uint256 assetIdxSeed, uint256 amount)
//         external
//         useActor(actorIdxSeed)
//         useAsset(assetIdxSeed)
//         countCall("unloadToUser")
//     {
//         vm.assume(currentAsset.standard == ERC20_STANDARD);
//         amount = bound(amount, 0, type(uint128).max);

//         bytes memory parameters = abi.encode(PoolSupplyAccount.Parameters({user: currentActor}));

//         vm.prank(currentActor);
//         accountModule.unloadToUser(currentAsset, amount, parameters);

//         // Local tracking updates.
//         userEarningBalance[currentActor][currentAsset.addr] -= amount;
//         totalEarningBalance[currentAsset.addr] -= amount;
//         totalBalance[currentAsset.addr] -= amount;
//     }

//     function loadToPosition(uint256 actorIdxSeed, uint256 assetIdxSeed, uint256 amount, address position)
//         external
//         payable
//         useActor(actorIdxSeed)
//         useAsset(assetIdxSeed)
//         countCall("loadToPosition")
//     {
//         vm.assume(currentAsset.standard == ERC20_STANDARD);
//         amount = bound(amount, 0, type(uint128).max);

//         bytes memory parameters = abi.encode(PoolSupplyAccount.Parameters({user: currentActor}));

//         vm.assume(accountModule.getBalance(currentAsset, parameters) >= amount);

//         vm.prank(bookkeeperAddr);
//         accountModule.loadFromPosition(currentAsset, amount, parameters);

//         // // Local tracking updates.
//         // userEarningBalance[currentActor][currentAsset.addr] -= ???
//         // totalEarningBalance[currentAsset.addr] -= ???
//         // totalBalance[currentAsset.addr] -= ???
//     }

//     // Assets could come in from positions that were never touched by users.
//     function loadFromPosition(uint256 actorIdxSeed, uint256 assetIdxSeed, uint256 amount, address position)
//         external
//         payable
//         useActor(actorIdxSeed)
//         useAsset(assetIdxSeed)
//         countCall("loadFromPosition")
//     {
//         vm.assume(currentAsset.standard == ERC20_STANDARD);
//         amount = bound(amount, 0, type(uint128).max);

//         bytes memory parameters = abi.encode(PoolSupplyAccount.Parameters({user: currentActor}));

//         dealAsset(currentAsset, msg.sender, amount);
//         vm.prank(position);
//         IERC20(currentAsset.addr).approve(address(accountModule), amount);

//         vm.prank(bookkeeperAddr);
//         accountModule.loadFromPosition(currentAsset, amount, parameters);

//         // Local tracking updates.
//         totalBalance[currentAsset.addr] += amount;
//     }
// }

// contract InvariantAccountTest is Test {
//     Handler public handler;
//     mapping(bytes32 => bool) touchedAccounts;

//     // invoked before each test case is run
//     function setUp() public {
//         vm.recordLogs();
//         vm.createSelectFork(vm.rpcUrl("mainnet"), 17092863);
//         handler = new Handler();

//         // vm.targetContract(address(handler)); // how to do in 0.2.0?

//         // bytes4[] memory selectors = new bytes4[](3);
//         // selectors[0] = Handler.load.selector;
//         // selectors[1] = Handler.unload.selector;

//         // targetSelectors(FuzzSelector({addr: address(handler), selectors: selectors}));

//         // targetContract(address(handler));
//     }

//     function invariant_ExpectedCumulativeBalances() public {
//         for (uint256 i; i < handler.actorsLength(); i++) {
//             address actor = handler.actors(i);
//             for (uint256 j; j < handler.assetsLength(); j++) {
//                 (bytes3 standard, address addr, uint8 decimals, uint256 id, bytes memory data) = handler.assets(j);
//                 Asset memory asset = Asset({standard: standard, addr: addr, decimals: decimals, id: id, data: data});
//                 if (asset.standard != ERC20_STANDARD) {
//                     continue;
//                 }

//                 bytes memory parameters = abi.encode(PoolSupplyAccount.Parameters({user: actor}));
//                 assertEq(
//                     C.RATIO_FACTOR * handler.totalBalance(asset.addr) * handler.userEarningBalance(actor, asset.addr)
//                         / handler.totalEarningBalance(asset.addr),
//                     C.RATIO_FACTOR * handler.accountModule().getBalance(asset, parameters)
//                 );
//             }
//         }

//         // POSSIBLE INVARIANT: If all positions close and all users withdraw, account balance == 0.
//     }

//     function invariant_callSummary() public view {
//         handler.callSummary();
//     }
// }

*/