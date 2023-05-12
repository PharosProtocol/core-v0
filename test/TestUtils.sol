// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "forge-std/Test.sol";

contract TestUtils is Test {
    // modifier requireFork() {
    //     vm.activeFork();
    //     _;
    // }

    // modifier startPrank(address pranker) {
    //     vm.startPrank(pranker);
    //     _;
    // }
}

contract HandlerUtils is Test {
    mapping(bytes32 => uint256) public calls;
    address[] public actors;
    address internal currentActor;

    modifier createActor() {
        vm.assume(msg.sender != address(0));
        currentActor = msg.sender;
        actors.push(msg.sender);
        _;
    }

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
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
}