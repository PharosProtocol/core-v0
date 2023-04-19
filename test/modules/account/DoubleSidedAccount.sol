// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
 * comprehensive as each unique implementation will likely need its own unique tests.
 */

import "forge-std/Test.sol";
import {HandlerUtils} from "test/TestUtils.sol";

// import {TestUtils} from "test/LibTestUtils.sol";

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {C} from "src/C.sol";
import {Asset, AssetStandard, ETH_STANDARD, ERC20_STANDARD} from "src/LibUtil.sol";
import {DoubleSidedAccount} from "src/modules/account/implementations/DoubleSidedAccount.sol";

contract AccountTest is Test {
    DoubleSidedAccount public accountModule;
    Asset[] ASSETS;

    // Copy of event definitions.
    event AssetAdded(address owner, bytes32 salt, Asset asset, uint256 amount);
    event AssetRemoved(address owner, bytes32 salt, Asset asset, uint256 amount);

    constructor() {
        ASSETS.push(Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""}));
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.USDC, id: 0, data: ""}));
    }

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        // requires fork
        vm.activeFork();
        accountModule = new DoubleSidedAccount();
    }

    // NOTE it is unclear if this should be a fuzz or a direct unit tests. Are fuzzes handled by invariant tests?
    function test_UserCalls(uint256 assetIdx, uint256 amount, bytes32 salt) public {
        vm.assume(msg.sender != address(0));
        assetIdx = bound(assetIdx, 0, ASSETS.length - 1);
        amount = bound(amount, 0, type(uint128).max);

        vm.startPrank(msg.sender);

        // Set ETH balance.
        uint256 value;
        if (ASSETS[assetIdx].standard == ETH_STANDARD) {
            vm.deal(msg.sender, amount);
            value = amount;
        }
        // Set ERC20 balance.
        if (ASSETS[assetIdx].standard == ERC20_STANDARD) {
            // vm.assume(amount != 0);
            deal(ASSETS[assetIdx].addr, msg.sender, amount, true);
            // vm.prank(msg.sender);
            IERC20(ASSETS[assetIdx].addr).approve(address(accountModule), amount);
        }

        bytes memory parameters = abi.encode(DoubleSidedAccount.Parameters({owner: msg.sender, salt: salt}));

        // vm.prank(msg.sender);
        accountModule.addAsset{value: value}(ASSETS[assetIdx], amount, parameters);

        assertEq(accountModule.getOwner(parameters), msg.sender);
        assertEq(accountModule.getBalance(ASSETS[assetIdx], parameters), amount); // NOTE this should fail sometimes

        accountModule.removeAsset(ASSETS[assetIdx], amount, parameters);
        assertEq(accountModule.getBalance(ASSETS[assetIdx], parameters), 0);

        // Revert because account empty.
        vm.expectRevert(stdError.arithmeticError);
        accountModule.removeAsset(ASSETS[0], 1, parameters);

        // Revert because non-owned account.
        vm.stopPrank();
        vm.prank(address(123)); // random addr
        vm.expectRevert();
        accountModule.removeAsset(ASSETS[0], 1, parameters);
    }
}

contract Handler is Test, HandlerUtils {
    DoubleSidedAccount public accountModule;
    Asset[] public ASSETS;
    uint256[] public assetBalances;
    // uint256[] public assetsIn;
    // uint256[] public assetsOut;

    constructor() {
        ASSETS.push(Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""}));
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.USDC, id: 0, data: ""}));
        assetBalances = new uint256[](ASSETS.length);
        accountModule = new DoubleSidedAccount();
    }

    function addAsset(uint256 assetIdx, uint256 amount, address owner, bytes32 salt)
        external
        payable
        createActor
        countCall("addAsset")
    {
        assetIdx = bound(assetIdx, 0, ASSETS.length - 1);
        amount = bound(amount, 0, type(uint128).max);
        Asset memory asset = ASSETS[assetIdx];
        bytes memory parameters = abi.encode(DoubleSidedAccount.Parameters({owner: owner, salt: salt}));
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
        accountModule.addAsset{value: value}(asset, amount, parameters);
    }

    function removeAsset(uint256 actorIndexSeed, uint256 assetIdx, uint256 amount, address owner, bytes32 salt)
        external
        useActor(actorIndexSeed)
        countCall("removeAsset")
    {
        assetIdx = bound(assetIdx, 0, ASSETS.length - 1);
        amount = bound(amount, 0, type(uint128).max);
        Asset memory asset = ASSETS[assetIdx];
        bytes memory parameters = abi.encode(DoubleSidedAccount.Parameters({owner: owner, salt: salt}));
        assetBalances[assetIdx] -= amount; // NOTE how does invariant behave on reverts? will this protect lower failures?

        vm.prank(currentActor);
        accountModule.removeAsset(asset, amount, parameters);
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
        // requires fork
        vm.activeFork();
        handler = new Handler();

        // vm.targetContract(address(handler)); // how to do in 0.2.0?

        // bytes4[] memory selectors = new bytes4[](3);
        // selectors[0] = Handler.addAsset.selector;
        // selectors[1] = Handler.removeAsset.selector;

        // targetSelectors(FuzzSelector({addr: address(handler), selectors: selectors}));

        // targetContract(address(handler));
    }

    function invariant_ExpectedCumulativeBalances() public {
        for (uint256 j; j < handler.assetsLength(); j++) {
            (bytes3 standard, address addr,,) = handler.ASSETS(j);
            if (standard == ETH_STANDARD) {
                assertEq(address(handler.accountModule()).balance, handler.assetBalances(j));
            }
            // else if (standard == ERC20_STANDARD) {
            //     assertEq(IERC20(addr).balanceOf(address(handler.accountModule())), handler.assetBalances(j));
            // }
        }
    }

    function invariant_callSummary() public view {
        handler.callSummary();
    }
}
