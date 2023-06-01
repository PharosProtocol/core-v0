// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
 * comprehensive as each unique implementation will likely need its own unique tests.
 */

import "forge-std/Test.sol";
import {HandlerUtils} from "test/TestUtils.sol";
import {MockPosition} from "test/mocks/MockPosition.sol";

// import {TestUtils} from "test/LibTestUtils.sol";

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "src/LibUtil.sol";
import {C} from "src/C.sol";
import {Asset, AssetStandard, ETH_STANDARD, ERC20_STANDARD} from "src/LibUtil.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {StandardAssessor} from "src/modules/assessor/implementations/StandardAssessor.sol";

contract StandardAssessorTest is Test {
    StandardAssessor public assessorModule;
    MockPosition public position;

    constructor() {}

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        // // requires fork
        // vm.activeFork();
        vm.createSelectFork(vm.rpcUrl("mainnet"), 17092863); // seems that test begin at end of block.
        assessorModule = new StandardAssessor();
    }

    function getCost(
        uint256 originationFeeRatio,
        uint256 interestRatio,
        uint256 profitShareRatio,
        uint256 loanAmount,
        uint256 currentValueRatio,
        uint256 timePassed
    ) private returns (uint256) {
        position = new MockPosition(address(0), loanAmount * currentValueRatio / C.RATIO_FACTOR);

        Agreement memory agreement;
        agreement.loanAmount = loanAmount;
        // agreement.factory.parameters =
        agreement.position.addr = address(position);
        agreement.deploymentTime = block.timestamp - timePassed;
        console.log("deploymentTime: %s", agreement.deploymentTime);

        StandardAssessor.Parameters memory parameters = StandardAssessor.Parameters({
            originationFeeRatio: originationFeeRatio,
            interestRatio: interestRatio,
            profitShareRatio: profitShareRatio
        });
        agreement.assessor = ModuleReference({addr: address(assessorModule), parameters: abi.encode(parameters)});
        return assessorModule.getCost(agreement, position.getCloseAmount(agreement.position.parameters));
    }

    /// @notice manual defined test cases of getCost. Checks for correctness.
    function test_GetCost() public {
        uint256 loanAmount = 100e18;
        uint256 timePassed = 24 * 60 * 60;

        uint256 cost;

        cost = getCost(10 * C.RATIO_FACTOR / 100, 0, 0, loanAmount, 1, timePassed); // 10% origination fee
        assertEq(cost, loanAmount / 10); // certainly going to have rounding error here
        cost = getCost(0, C.RATIO_FACTOR / 1_000_000, 0, loanAmount, 1, timePassed); // 0.0001% interest per second for 1 day
        assertEq(cost, loanAmount * timePassed / 1_000_000); // rounding errors?
        cost = getCost(0, 0, 5 * C.RATIO_FACTOR / 100, loanAmount, 120 * C.RATIO_FACTOR / 100, timePassed); // 5% of 20% profit
        assertEq(cost, loanAmount * 20 * 5 / 100 / 100); // rounding errors?
        cost = getCost(0, 0, 5 * C.RATIO_FACTOR / 100, loanAmount, 90 * C.RATIO_FACTOR / 100, timePassed); // 5% of 10% loss
        assertEq(cost, 0);
    }

    /// @notice fuzz testing of getCost. Does not check for correctness.
    function testFuzz_GetCost(
        uint256 originationFeeRatio,
        uint256 interestRatio,
        uint256 profitShareRatio,
        uint256 loanAmount,
        uint256 currentValueRatio,
        uint256 timePassed,
        uint256 scaleUpRatio
    ) public {
        originationFeeRatio = bound(originationFeeRatio, 0, C.RATIO_FACTOR);
        interestRatio = bound(interestRatio, 0, C.RATIO_FACTOR);
        profitShareRatio = bound(profitShareRatio, 0, C.RATIO_FACTOR);
        loanAmount = bound(loanAmount, 0, type(uint64).max);
        currentValueRatio = bound(currentValueRatio, 0, 3 * C.RATIO_FACTOR);
        timePassed = bound(timePassed, 0, 365 * 24 * 60 * 60);
        uint256 cost =
            getCost(originationFeeRatio, interestRatio, profitShareRatio, loanAmount, currentValueRatio, timePassed);
        uint256 currentValue = loanAmount * currentValueRatio / C.RATIO_FACTOR;

        {
            // assertLe(cost, loanAmount); // May not be true if cost parameters v high.
            uint256 originationFee = loanAmount * originationFeeRatio / C.RATIO_FACTOR;
            assertGe(cost, originationFee);
            uint256 interest = loanAmount * timePassed * interestRatio / C.RATIO_FACTOR;
            assertGe(cost, interest);
            uint256 nonProfitCost = loanAmount + originationFee + interest;
            if (currentValue > nonProfitCost) {
                uint256 profitShare = (currentValue - nonProfitCost) * profitShareRatio / C.RATIO_FACTOR;
                assertGe(cost, profitShare);
            }
        }

        {
            scaleUpRatio = bound(scaleUpRatio, 0, C.RATIO_FACTOR) + C.RATIO_FACTOR;
            uint256 loanAmountBig = loanAmount * scaleUpRatio / C.RATIO_FACTOR;
            uint256 timePassedBig = timePassed * scaleUpRatio / C.RATIO_FACTOR;
            assertLe(
                cost,
                getCost(
                    originationFeeRatio, interestRatio, profitShareRatio, loanAmountBig, currentValueRatio, timePassed
                )
            );
            assertLe(
                cost,
                getCost(
                    originationFeeRatio, interestRatio, profitShareRatio, loanAmount, currentValueRatio, timePassedBig
                )
            );
        }
    }
}
