// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 * This is a template for forge testing. Temporary dev reference only.
 */

import "forge-std/Test.sol";

contract ContractBTest is Test {
    uint256 testNumber;

    /// An optional function invoked before each test case is run.
    function setUp() public {
        vm.recordLogs(); // ?
    }

    /// Functions prefixed with test are run as a test case
    function test_ArbitraryName() public {
        // vm.startPrank(lender);
        assertEq(testNumber, 42);
    }

    /// Functions prefixed with test are run as a test case
    function testFuzz_ArbitraryName() public {
        // vm.bound();
        // vm.assume();
    }

    /// The inverse of the test prefix - if the function does not revert, the test fails
    /// NOTE that we consider this an anti-pattern. Instead use `expectRevert`.
    function testFail_ArbitraryName() public {
        testNumber -= 43;
    }

    /// An invariant test with runs and depth.
    function invariant_A() public {
        // assertEq(testNumber, 42);
    }
}
