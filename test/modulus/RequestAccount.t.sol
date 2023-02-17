// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "forge-std/Test.sol";

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
        vm.startPrank(borrower);
        requestAccountRegistry.createRequestAccount(_id, new bytes32[](0), new address[](0), new uint256[](0));
        assertEq(requestAccountRegistry.accountCount(), 1);
    }
}
