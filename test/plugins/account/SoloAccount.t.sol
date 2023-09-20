// SPDX-License-Identifier: MIT
// solhint-disable

pragma solidity 0.8.19;

/**
 * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
 * comprehensive as each unique implementation will likely need its own unique tests.
 */

import "@forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {HandlerUtils} from "test/TestUtils.sol";
import {TestUtils} from "test/TestUtils.sol";
import {C} from "src/libraries/C.sol";
import {TC} from "test/TC.sol";
import {Asset, ETH_STANDARD, ERC20_STANDARD} from "src/libraries/LibUtils.sol";
import {SoloAccount} from "src/plugins/account/implementations/SoloAccount.sol";

contract AccountTest is TestUtils {
    SoloAccount public accountPlugin;
    Asset[] ASSETS;

    // Copy of event definitions.
    event AssetAdded(address owner, bytes32 salt, Asset asset, uint256 amount);
    event AssetRemoved(address owner, bytes32 salt, Asset asset, uint256 amount);

    constructor() {
        // ASSETS.push(Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""})); // Tests expect 0 index to be ETH
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.WETH, decimals: 18, id: 0, data: ""})); // Tests expect 0 index to be WETH
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: TC.USDC, decimals: TC.USDC_DECIMALS, id: 0, data: ""})); // Tests expect 1 index to be an ERC20
    }

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl(TC.CHAIN_NAME), TC.BLOCK_NUMBER);
        accountPlugin = new SoloAccount(address(1));
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
        assertEq(accountPlugin.getOwner(parameters), msg.sender);

        // Fail to add WETH because balance too low.
        vm.expectRevert();
        accountPlugin.loadFromUser(ASSETS[0], 11e18, parameters);

        // Fail to add ERC20 because asset not approved.
        vm.expectRevert("safeErc20TransferFrom failed");
        accountPlugin.loadFromUser(ASSETS[1], 1e18, parameters);

        // Approve ERC20s.
        IERC20(ASSETS[0].addr).approve(address(accountPlugin), 999e18);
        IERC20(ASSETS[1].addr).approve(address(accountPlugin), 999e18);

        // Fail to add ERC20 because balance too low.
        vm.expectRevert("safeErc20TransferFrom failed");
        accountPlugin.loadFromUser(ASSETS[1], 11e18, parameters);

        // Add WETH.
        accountPlugin.loadFromUser{value: 0}(ASSETS[0], 1e18, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[0], parameters), 1e18);
        accountPlugin.loadFromUser{value: 0}(ASSETS[0], 3e18, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[0], parameters), 4e18);
        accountPlugin.loadFromUser{value: 0}(ASSETS[0], 1, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[0], parameters), 4000000000000000001);
        accountPlugin.loadFromUser{value: 0}(ASSETS[0], 0, parameters); // NOTE should this be made to revert?
        assertEq(accountPlugin.getBalance(ASSETS[0], parameters), 4000000000000000001);

        // Add ERC20.
        accountPlugin.loadFromUser{value: 0}(ASSETS[1], 1e18, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[1], parameters), 1e18);
        accountPlugin.loadFromUser{value: 0}(ASSETS[1], 3e18, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[1], parameters), 4e18);
        accountPlugin.loadFromUser{value: 0}(ASSETS[1], 1, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[1], parameters), 4000000000000000001);
        accountPlugin.loadFromUser{value: 0}(ASSETS[1], 0, parameters); // NOTE should this be made to revert?
        assertEq(accountPlugin.getBalance(ASSETS[1], parameters), 4000000000000000001);

        // Verify other balances are still valid.
        assertEq(accountPlugin.getBalance(ASSETS[0], parameters), 4000000000000000001);
        // assertEq(accountPlugin.getBalance(ASSETS[1], parameters), 4000000000000000001);

        // Remove WETH.
        accountPlugin.unloadToUser(ASSETS[0], 1, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[0], parameters), 4e18);
        accountPlugin.unloadToUser(ASSETS[0], 1e18, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[0], parameters), 3e18);
        accountPlugin.unloadToUser(ASSETS[0], 0, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[0], parameters), 3e18);
        accountPlugin.unloadToUser(ASSETS[0], 3e18, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[0], parameters), 0);

        // Remove ERC20.
        accountPlugin.unloadToUser(ASSETS[1], 1, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[1], parameters), 4e18);
        accountPlugin.unloadToUser(ASSETS[1], 1e18, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[1], parameters), 3e18);
        accountPlugin.unloadToUser(ASSETS[1], 0, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[1], parameters), 3e18);
        accountPlugin.unloadToUser(ASSETS[1], 3e18, parameters);
        assertEq(accountPlugin.getBalance(ASSETS[1], parameters), 0);

        // Revert because account empty.
        vm.expectRevert("_unloadToUser: balance too low");
        accountPlugin.unloadToUser(ASSETS[0], 1, parameters);
        vm.expectRevert("_unloadToUser: balance too low");
        accountPlugin.unloadToUser(ASSETS[1], 1, parameters);

        // Revert because non-owned account.
        vm.stopPrank();
        vm.prank(address(0)); // non msg.sender address
        vm.expectRevert("unload: not owner");
        accountPlugin.unloadToUser(ASSETS[0], 1, parameters);
    }
}

contract Handler is Test, HandlerUtils {
    SoloAccount public accountPlugin;
    Asset[] public ASSETS;
    uint256[] public assetBalances;

    // uint256[] public assetsIn;
    // uint256[] public assetsOut;

    constructor() {
        // ASSETS.push(Asset({standard: ETH_STANDARD, decimals: 18, addr: address(0), id: 0, data: ""}));
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.WETH, decimals: 18, id: 0, data: ""}));
        ASSETS.push(Asset({standard: ERC20_STANDARD, decimals: TC.USDC_DECIMALS, addr: TC.USDC, id: 0, data: ""}));
        assetBalances = new uint256[](ASSETS.length);
        accountPlugin = new SoloAccount(address(1));
    }

    function load(
        uint256 assetIdx,
        uint256 amount,
        address owner,
        bytes32 salt
    ) external payable createActor countCall("load") {
        assetIdx = bound(assetIdx, 0, ASSETS.length - 1);
        amount = bound(amount, 0, type(uint128).max);
        Asset memory asset = ASSETS[assetIdx];
        bytes memory parameters = abi.encode(SoloAccount.Parameters({owner: owner, salt: salt}));

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
            IERC20(asset.addr).approve(address(accountPlugin), amount);
        }

        vm.prank(currentActor);
        accountPlugin.loadFromUser{value: value}(asset, amount, parameters);

        assetBalances[assetIdx] += amount;
    }

    function unload(
        uint256 actorIndexSeed,
        uint256 assetIdx,
        uint256 amount,
        address owner,
        bytes32 salt
    ) external useActor(actorIndexSeed) countCall("unload") {
        assetIdx = bound(assetIdx, 0, ASSETS.length - 1);
        amount = bound(amount, 0, type(uint128).max);
        Asset memory asset = ASSETS[assetIdx];
        bytes memory parameters = abi.encode(SoloAccount.Parameters({owner: owner, salt: salt}));

        vm.prank(currentActor);
        accountPlugin.unloadToUser(asset, amount, parameters);

        assetBalances[assetIdx] -= amount; // NOTE how does invariant behave on reverts? will this protect lower failures?
    }

    /**
     * Helpers **
     */
    function _boundedAsset(uint8 assetIdx) private view returns (Asset memory) {
        return ASSETS[bound(assetIdx, 0, ASSETS.length - 1)];
    }

    function ASSETSLength() external view returns (uint256) {
        return ASSETS.length;
    }
}

contract InvariantAccountTest is Test {
    Handler public handler;
    mapping(bytes32 => bool) touchedAccounts;

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl(TC.CHAIN_NAME), TC.BLOCK_NUMBER);
        handler = new Handler();

        // vm.targetContract(address(handler)); // how to do in 0.2.0?

        // bytes4[] memory selectors = new bytes4[](3);
        // selectors[0] = Handler.load.selector;
        // selectors[1] = Handler.unload.selector;

        // targetSelectors(FuzzSelector({addr: address(handler), selectors: selectors}));

        // targetContract(address(handler));
    }

    function invariant_ExpectedCumulativeBalances() public {
        for (uint256 j; j < handler.ASSETSLength(); j++) {
            (bytes3 standard, address addr, , , ) = handler.ASSETS(j);
            if (standard == ETH_STANDARD || (standard == ERC20_STANDARD && addr == C.WETH)) {
                assertEq(address(handler.accountPlugin()).balance, handler.assetBalances(j));
            } else if (standard == ERC20_STANDARD) {
                assertEq(IERC20(addr).balanceOf(address(handler.accountPlugin())), handler.assetBalances(j));
            }
        }
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
