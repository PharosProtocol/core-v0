// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
 * comprehensive as each unique implementation will likely need its own unique tests.
 */

import "forge-std/Test.sol";
import {HandlerUtils} from "test/TestUtils.sol";
import {TestUtils} from "test/TestUtils.sol";

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {C} from "src/C.sol";
import {Asset, AssetStandard, ETH_STANDARD, ERC20_STANDARD} from "src/LibUtil.sol";
import {SoloAccount} from "src/modules/account/implementations/SoloAccount.sol";

contract AccountTest is TestUtils {
    SoloAccount public accountModule;
    Asset[] ASSETS;

    // Copy of event definitions.
    event AssetAdded(address owner, bytes32 salt, Asset asset, uint256 amount);
    event AssetRemoved(address owner, bytes32 salt, Asset asset, uint256 amount);

    constructor() {
        // ASSETS.push(Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""})); // Tests expect 0 index to be ETH
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.WETH, id: 0, data: ""})); // Tests expect 0 index to be WETH
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.USDC, id: 0, data: ""})); // Tests expect 1 index to be an ERC20
    }

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl("mainnet"), 17092863);
        accountModule = new SoloAccount(address(1));
    }

    // NOTE it is unclear if this should be a fuzz or a direct unit tests. Are fuzzes handled by invariant tests?
    function test_UserCalls() public {
        vm.assume(msg.sender != address(0));

        // Deal 10e18 of each asset.
        for (uint256 i; i < ASSETS.length; i++) {
            if (ASSETS[i].standard == ETH_STANDARD) {
                vm.deal(msg.sender, 10e18);
            } else if (ASSETS[i].standard == ERC20_STANDARD) {
                if (ASSETS[i].addr == C.WETH) {
                    wethDeal(msg.sender, 10e18);
                } else {
                    deal(ASSETS[i].addr, msg.sender, 10e18, true);
                }
            } else {
                revert("unsupported asset, cannot deal");
            }
        }

        vm.startPrank(msg.sender);

        // Define account instance.
        bytes memory parameters = abi.encode(SoloAccount.Parameters({owner: msg.sender, salt: "salt"}));
        assertEq(accountModule.getOwner(parameters), msg.sender);

        // Fail to add WETH because balance too low.
        vm.expectRevert();
        accountModule.loadFromUser(ASSETS[0], 11e18, parameters);

        // Fail to add ERC20 because asset not approved.
        vm.expectRevert("safeErc20TransferFrom failed");
        accountModule.loadFromUser(ASSETS[1], 1e18, parameters);

        // Approve ERC20s.
        IERC20(ASSETS[0].addr).approve(address(accountModule), 999e18);
        IERC20(ASSETS[1].addr).approve(address(accountModule), 999e18);

        // Fail to add ERC20 because balance too low.
        vm.expectRevert("safeErc20TransferFrom failed");
        accountModule.loadFromUser(ASSETS[1], 11e18, parameters);

        // Add WETH.
        accountModule.loadFromUser{value: 0}(ASSETS[0], 1e18, parameters);
        assertEq(accountModule.getBalance(ASSETS[0], parameters), 1e18);
        accountModule.loadFromUser{value: 0}(ASSETS[0], 3e18, parameters);
        assertEq(accountModule.getBalance(ASSETS[0], parameters), 4e18);
        accountModule.loadFromUser{value: 0}(ASSETS[0], 1, parameters);
        assertEq(accountModule.getBalance(ASSETS[0], parameters), 4000000000000000001);
        accountModule.loadFromUser{value: 0}(ASSETS[0], 0, parameters); // NOTE should this be made to revert?
        assertEq(accountModule.getBalance(ASSETS[0], parameters), 4000000000000000001);

        // Add ERC20.
        accountModule.loadFromUser{value: 0}(ASSETS[1], 1e18, parameters);
        assertEq(accountModule.getBalance(ASSETS[1], parameters), 1e18);
        accountModule.loadFromUser{value: 0}(ASSETS[1], 3e18, parameters);
        assertEq(accountModule.getBalance(ASSETS[1], parameters), 4e18);
        accountModule.loadFromUser{value: 0}(ASSETS[1], 1, parameters);
        assertEq(accountModule.getBalance(ASSETS[1], parameters), 4000000000000000001);
        accountModule.loadFromUser{value: 0}(ASSETS[1], 0, parameters); // NOTE should this be made to revert?
        assertEq(accountModule.getBalance(ASSETS[1], parameters), 4000000000000000001);

        // Verify other balances are still valid.
        assertEq(accountModule.getBalance(ASSETS[0], parameters), 4000000000000000001);
        // assertEq(accountModule.getBalance(ASSETS[1], parameters), 4000000000000000001);

        // Remove WETH.
        accountModule.unloadToUser(ASSETS[0], 1, parameters);
        assertEq(accountModule.getBalance(ASSETS[0], parameters), 4e18);
        accountModule.unloadToUser(ASSETS[0], 1e18, parameters);
        assertEq(accountModule.getBalance(ASSETS[0], parameters), 3e18);
        accountModule.unloadToUser(ASSETS[0], 0, parameters);
        assertEq(accountModule.getBalance(ASSETS[0], parameters), 3e18);
        accountModule.unloadToUser(ASSETS[0], 3e18, parameters);
        assertEq(accountModule.getBalance(ASSETS[0], parameters), 0);

        // Remove ERC20.
        accountModule.unloadToUser(ASSETS[1], 1, parameters);
        assertEq(accountModule.getBalance(ASSETS[1], parameters), 4e18);
        accountModule.unloadToUser(ASSETS[1], 1e18, parameters);
        assertEq(accountModule.getBalance(ASSETS[1], parameters), 3e18);
        accountModule.unloadToUser(ASSETS[1], 0, parameters);
        assertEq(accountModule.getBalance(ASSETS[1], parameters), 3e18);
        accountModule.unloadToUser(ASSETS[1], 3e18, parameters);
        assertEq(accountModule.getBalance(ASSETS[1], parameters), 0);

        // Revert because account empty.
        vm.expectRevert(stdError.arithmeticError);
        accountModule.unloadToUser(ASSETS[0], 1, parameters);
        vm.expectRevert(stdError.arithmeticError);
        accountModule.unloadToUser(ASSETS[1], 1, parameters);

        // Revert because non-owned account.
        vm.stopPrank();
        vm.prank(address(123)); // random addr
        vm.expectRevert("unload: not owner");
        accountModule.unloadToUser(ASSETS[0], 1, parameters);
    }
}

contract Handler is Test, HandlerUtils {
    SoloAccount public accountModule;
    Asset[] public ASSETS;
    uint256[] public assetBalances;
    // uint256[] public assetsIn;
    // uint256[] public assetsOut;

    constructor() {
        ASSETS.push(Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""}));
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.USDC, id: 0, data: ""}));
        assetBalances = new uint256[](ASSETS.length);
        accountModule = new SoloAccount(address(1));
    }

    function load(uint256 assetIdx, uint256 amount, address owner, bytes32 salt)
        external
        payable
        createActor
        countCall("load")
    {
        assetIdx = bound(assetIdx, 0, ASSETS.length - 1);
        amount = bound(amount, 0, type(uint128).max);
        Asset memory asset = ASSETS[assetIdx];
        bytes memory parameters = abi.encode(SoloAccount.Parameters({owner: owner, salt: salt}));
        assetBalances[assetIdx] += amount;

        // Set ETH balance.
        uint256 value;
        if (asset.standard == ETH_STANDARD) {
            vm.deal(currentActor, amount);
            value = amount;
        }
        // Set ERC20 balance.
        if (asset.standard == ERC20_STANDARD) {
            // vm.assume(amount != 0);
            deal(asset.addr, currentActor, amount, true);
            IERC20(asset.addr).approve(address(accountModule), amount);
        }

        vm.prank(currentActor);
        accountModule.loadFromUser{value: value}(asset, amount, parameters);
    }

    function unload(uint256 actorIndexSeed, uint256 assetIdx, uint256 amount, address owner, bytes32 salt)
        external
        useActor(actorIndexSeed)
        countCall("unload")
    {
        assetIdx = bound(assetIdx, 0, ASSETS.length - 1);
        amount = bound(amount, 0, type(uint128).max);
        Asset memory asset = ASSETS[assetIdx];
        bytes memory parameters = abi.encode(SoloAccount.Parameters({owner: owner, salt: salt}));
        assetBalances[assetIdx] -= amount; // NOTE how does invariant behave on reverts? will this protect lower failures?

        vm.prank(currentActor);
        accountModule.unloadToUser(asset, amount, parameters);
    }

    /**
     * Helpers **
     */
    function _boundedAsset(uint8 assetIdx) private view returns (Asset memory) {
        return ASSETS[bound(assetIdx, 0, ASSETS.length - 1)];
    }

    function assetsLength() external view returns (uint256) {
        return ASSETS.length;
    }
}

contract InvariantAccountTest is Test {
    Handler public handler;
    mapping(bytes32 => bool) touchedAccounts;

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl("mainnet"), 17092863);
        handler = new Handler();

        // vm.targetContract(address(handler)); // how to do in 0.2.0?

        // bytes4[] memory selectors = new bytes4[](3);
        // selectors[0] = Handler.load.selector;
        // selectors[1] = Handler.unload.selector;

        // targetSelectors(FuzzSelector({addr: address(handler), selectors: selectors}));

        // targetContract(address(handler));
    }

    function invariant_ExpectedCumulativeBalances() public {
        for (uint256 j; j < handler.assetsLength(); j++) {
            (bytes3 standard, address addr,,) = handler.ASSETS(j);
            if (standard == ETH_STANDARD) {
                assertEq(address(handler.accountModule()).balance, handler.assetBalances(j));
            } else if (standard == ERC20_STANDARD) {
                assertEq(IERC20(addr).balanceOf(address(handler.accountModule())), handler.assetBalances(j));
            }
        }
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
