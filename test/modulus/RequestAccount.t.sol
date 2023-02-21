// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "lib/forge-std/src/Test.sol";

import {RequestAccount, RequestAccountRegistry} from "src/modulus/RequestAccount.sol";

contract RequestAccountTest is Test {
    RequestAccountRegistry public requestAccountRegistry;
    // uint8 public numAssets = 4;
    address[] assets;
    uint256[] amounts;
    uint256 constant maxAssets = 4;

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        requestAccountRegistry = new RequestAccountRegistry();
    }

    function test_createEmptyRequestAccount(address borrower, bytes32 _id) public {
        vm.assume(borrower != address(0));
        vm.startPrank(borrower);
        requestAccountRegistry.createRequestAccount(
            _id, new bytes32[](0), new address[](0), new uint256[](0), new address[](0), 0
        );
        (address borrowerChecked,) = requestAccountRegistry.accounts(_id); // borrower is at struct index 0. seems dangerous to define this way.
        assertTrue(borrowerChecked != address(0));
    }
}
