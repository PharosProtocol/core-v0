// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "forge-std/Test.sol";

import {C} from "src/libraries/C.sol";
import {IWETH9} from "src/interfaces/external/IWETH9.sol";
import {Asset, ETH_STANDARD, ERC20_STANDARD} from "src/libraries/LibUtils.sol";

contract TestUtils is Test {
    // modifier requireFork() {
    //     vm.activeFork();
    //     _;
    // }

    // modifier startPrank(address pranker) {
    //     vm.startPrank(pranker);
    //     _;
    // }

    function wethDeal(address addr, uint256 amount) internal {
        vm.deal(addr, amount);
        vm.prank(addr);
        IWETH9(C.WETH).deposit{value: amount}();
    }

    // Override forge deal to handle WETH.
    function dealErc20(address token, address to, uint256 amount) internal {
        if (token == C.WETH) {
            wethDeal(to, amount);
        } else {
            deal(token, to, amount, true);
        }
    }

    function dealAsset(Asset memory asset, address to, uint256 amount) internal {
        if (asset.standard == ETH_STANDARD) {
            vm.deal(to, amount);
        } else if (asset.standard == ERC20_STANDARD) {
            dealErc20(asset.addr, to, 10e18);
        } else {
            revert("dealAsset: unsupported asset");
        }
    }
}

contract HandlerUtils is TestUtils {
    Asset NULL_ASSET;

    mapping(bytes32 => uint256) public calls;
    address[] public actors;
    address internal currentActor;
    Asset[] public assets;
    Asset internal currentAsset;

    constructor() {
        // ASSETS.push(Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""})); // Tests expect 0 index to be ETH
        assets.push(Asset({standard: ERC20_STANDARD, addr: C.WETH, decimals: 18, id: 0, data: ""})); // Tests expect 0 index to be WETH
        assets.push(Asset({standard: ERC20_STANDARD, addr: C.USDC, decimals: C.USDC_DECIMALS, id: 0, data: ""})); // Tests expect 1 index to be an ERC20
    }

    modifier createActor() {
        vm.assume(msg.sender != address(0));
        currentActor = msg.sender;
        actors.push(msg.sender);
        _;
    }

    modifier useActor(uint256 actorIdxSeed) {
        currentActor = actors[bound(actorIdxSeed, 0, actors.length - 1)];
        _;
        currentActor = address(0);
    }

    modifier useAsset(uint256 assetIdxSeed) {
        currentAsset = assets[bound(assetIdxSeed, 0, assets.length - 1)];
        _;
        currentAsset = NULL_ASSET;
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    function callSummary() external view {
        console.log("Call summary:");
        console.log("-------------------");
        console.log("deposit", calls["deposit"]);
        console.log("withdraw", calls["withdraw"]);
        console.log("sendFallback", calls["sendFallback"]);
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }

    function assetsLength() external view returns (uint256) {
        return assets.length;
    }
}
