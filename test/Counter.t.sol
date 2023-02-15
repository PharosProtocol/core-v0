// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Counter.sol";

contract CounterTest is Test {
    Counter public counter;

    // invoked before each test case is run
    function setUp() public {
        counter = new Counter();
        counter.setNumber(0);
    }

    function test_increment() public {
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function test_setNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }

    function test_OwnerIncrementAsOwner() public {
        counter.ownerIncrement();
        assertEq(counter.number(), 2);
    }

    function test_OwnerIncrementAsNotOwner(address sender) public {
        vm.assume(sender != counter.owner());
        vm.expectRevert();
        vm.prank(sender);
        // console.log('owner:');
        // address a = counter.owner();
        // console.log("address: %s", a);
        counter.ownerIncrement();
    }
}
