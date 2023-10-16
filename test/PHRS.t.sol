// SPDX-License-Identifier: MIT
// solhint-disable

pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import "@forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PharosToken}from "src/libraries/PHRS-ERC20.sol";
import {TestUtils} from "test/TestUtils.sol";
import {C} from "src/libraries/C.sol";
import {TC} from "test/TC.sol";


contract FillAndClose is TestUtils {
    PharosToken public phrs;
   

    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl(TC.CHAIN_NAME), TC.BLOCK_NUMBER); // NOTE ensure this is more recent than deployments.

        address[] memory initialHolders = new address[](2);
        initialHolders[0] = 0xFc6FD3012BF5349ccF44683A8875907c0b8B7cD2;
        initialHolders[1] = 0x1e25D2596d02cbD6AEd54994FDF2Df7239C8C4Dc;


        uint256[] memory initialBalances = new uint256[](2);
        initialBalances[0] = 100;
        initialBalances[1] = 500;


        phrs = new PharosToken(initialHolders, initialBalances);

    }


    // test oracle
    function test_phrs_erc20() public {

        console.log("balance of holder1",IERC20(address(phrs)).balanceOf(0xFc6FD3012BF5349ccF44683A8875907c0b8B7cD2));
        console.log("balance of holder2",IERC20(address(phrs)).balanceOf(0x1e25D2596d02cbD6AEd54994FDF2Df7239C8C4Dc));

    }

}
