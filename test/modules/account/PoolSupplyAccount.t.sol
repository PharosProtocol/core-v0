// // SPDX-License-Identifier: UNLICENSED

// pragma solidity 0.8.19;

// /**
//  * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
//  * comprehensive as each unique implementation will likely need its own unique tests.
//  */

// import "forge-std/Test.sol";
// import {HandlerUtils} from "test/TestUtils.sol";
// import {TestUtils} from "test/TestUtils.sol";

// import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// import {C} from "src/libraries/C.sol";
// import {Asset, ETH_STANDARD, ERC20_STANDARD} from "src/libraries/LibUtils.sol";
// import {Order} from "src/libraries/LibBookkeeper.sol";
// import {PoolSupplyAccount} from "src/modules/account/implementations/PoolSupplyAccount.sol";

// contract PoolSupplyAccountTest is TestUtils {
//     PoolSupplyAccount public accountModule;
//     Asset[] ASSETS;

//     // Copy of events definitions.
//     event LoadedFromUser(Asset asset, uint256 amount, bytes parameters);
//     event LoadedFromPosition(Asset asset, uint256 amount, bytes parameters);
//     event UnloadedToUser(Asset asset, uint256 amount, bytes parameters);
//     event UnloadedToPosition(address position, Asset asset, uint256 amount, bool isLockedColl, bytes parameters);
//     event LockedCollateral(Asset asset, uint256 amount, bytes parameters);
//     event UnlockedCollateral(Asset asset, uint256 amount, bytes parameters);

//     constructor() {
//         // ASSETS.push(Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""})); // Tests expect 0 index to be ETH
//         ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.WETH, decimals: 18, id: 0, data: ""})); // Tests expect 0 index to be WETH
//         ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.USDC, decimals: C.USDC_DECIMALS, id: 0, data: ""})); // Tests expect 1 index to be an ERC20
//     }

//     // invoked before each test case is run
//     function setUp() public {
//         vm.recordLogs();
//         vm.createSelectFork(vm.rpcUrl("mainnet"), 17092863);
//         Order[] memory orders;
//         accountModule = new PoolSupplyAccount(address(99999), orders);
//     }

//     // NOTE it is unclear if this should be a fuzz or a direct unit tests. Are fuzzes handled by invariant tests?
//     function test_UserCalls() public {
//         vm.assume(msg.sender != address(0));

//         // Deal 10e18 of each asset.
//         for (uint256 i; i < ASSETS.length; i++) {
//             if (ASSETS[i].standard == ETH_STANDARD) {
//                 vm.deal(msg.sender, 10e18);
//             } else {
//                 dealErc20(ASSETS[i].addr, msg.sender, 10e18);
//             }
//         }

//         vm.startPrank(msg.sender);

//         // Define account instance.
//         bytes memory parameters = abi.encode(PoolSupplyAccount.Parameters({user: msg.sender}));
//         assertEq(accountModule.getOwner(parameters), address(accountModule));

//         // Fail to add WETH because asset not approved.
//         vm.expectRevert("UtilsPublic.safeErc20TransferFrom failed");
//         accountModule.loadFromUser(ASSETS[0], 5e18, parameters);

//         // Fail to add ERC20 because asset not approved.
//         vm.expectRevert("UtilsPublic.safeErc20TransferFrom failed");
//         accountModule.loadFromUser(ASSETS[1], 5e18, parameters);

//         // Approve ERC20s.
//         IERC20(ASSETS[0].addr).approve(address(accountModule), 999e18);
//         IERC20(ASSETS[1].addr).approve(address(accountModule), 999e18);

//         // Fail to add ERC20 because balance too low.
//         vm.expectRevert("UtilsPublic.safeErc20TransferFrom failed");
//         accountModule.loadFromUser(ASSETS[0], 11e18, parameters);

//         // Add WETH.
//         accountModule.loadFromUser{value: 0}(ASSETS[0], 4e18, parameters);
//         assertEq(accountModule.getBalance(ASSETS[0], parameters), 1e18);

//         // Add ERC20.
//         accountModule.loadFromUser{value: 0}(ASSETS[1], 4e18, parameters);
//         assertEq(accountModule.getBalance(ASSETS[1], parameters), 1e18);

//         // Load from fake position.
//         accountModule.loadFromPosition(ASSETS[1], 4e18, parameters);
//         assertEq(accountModule.getBalance(ASSETS[0], parameters), 4e18);
//         assertEq(accountModule.getBalance(ASSETS[1], parameters), 8e18);

//         // Unload loan asset to fake position.
//         accountModule.unloadToPosition(address(1), ASSETS[0], 1e18, false, parameters);
//         assertEq(accountModule.getBalance(ASSETS[0], parameters), 3e18);
//         assertEq(accountModule.getBalance(ASSETS[1], parameters), 8e18);

//         // Fail to lock collateral. Not compatible.
//         vm.expectRevert("PoolAccount: Not compatible with borrowing");
//         accountModule.lockCollateral(ASSETS[1], 2e18, parameters);

//         // Fail to unlock collateral. Not compatible.
//         vm.expectRevert("PoolAccount: Not compatible with borrowing");
//         accountModule.unlockCollateral(ASSETS[1], 2e18, parameters);

//         // Fail to unload locked coll asset to fake position.
//         vm.expectRevert("PoolAccount: Not compatible with borrowing");
//         accountModule.unloadToPosition(address(1), ASSETS[1], 1e18, true, parameters);

//         // Remove WETH.
//         accountModule.unloadToUser(ASSETS[0], 3e18, parameters);
//         assertEq(accountModule.getBalance(ASSETS[0], parameters), 0e18);

//         // Remove ERC20.
//         accountModule.unloadToUser(ASSETS[1], 8e18, parameters);
//         assertEq(accountModule.getBalance(ASSETS[1], parameters), 0e18);

//         // Revert because account empty.
//         vm.expectRevert("_unloadToUser: balance too low");
//         accountModule.unloadToUser(ASSETS[0], 1, parameters);
//         vm.expectRevert("_unloadToUser: balance too low");
//         accountModule.unloadToUser(ASSETS[1], 1, parameters);

//         vm.stopPrank();

//         // Revert because non-owned account.
//         vm.prank(address(0)); // non msg.sender address
//         vm.expectRevert("unload: not owner");
//         accountModule.unloadToUser(ASSETS[0], 1, parameters);
//     }
// }

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
