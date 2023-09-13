// // SPDX-License-Identifier: MIT
// // solhint-disable

// pragma solidity 0.8.19;

// /**
//  * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
//  * comprehensive as each unique implementation will likely need its own unique tests.
//  */

// import "@forge-std/Test.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {HandlerUtils} from "test/TestUtils.sol";
// import {MockPosition} from "test/mocks/MockPosition.sol";

// import {IPosition} from "src/interfaces/IPosition.sol";
// import {TC} from "test/TC.sol";
// import {C} from "src/libraries/C.sol";
// import {Agreement} from "src/libraries/LibBookkeeper.sol";
// import {Asset, ETH_STANDARD, ERC20_STANDARD, PluginReference} from "src/libraries/LibUtils.sol";
// import {StandardAssessor} from "src/plugins/assessor/implementations/StandardAssessor.sol";

// contract StandardAssessorTest is Test {
//     StandardAssessor public assessorPlugin;
//     IPosition public position;

//     constructor() {}

//     // invoked before each test case is run
//     function setUp() public {
//         vm.recordLogs();
//         // seems that test begin at end of block.
//         vm.createSelectFork(vm.rpcUrl(TC.CHAIN_NAME), TC.BLOCK_NUMBER);
//         assessorPlugin = new StandardAssessor();
//     }

//     function getCost(
//         uint256 originationFeeRatio,
//         uint256 interestRatio,
//         uint256 profitShareRatio,
//         uint256 loanAmount,
//         uint256 currentValueRatio,
//         uint256 timePassed
//     ) private returns (Asset memory asset, uint256 cost) {
//         Asset memory mockAsset;
//         MockPosition positionFactory = new MockPosition(address(1));
//         vm.prank(address(1));
//         position = IPosition(positionFactory.createClone());
//         vm.prank(address(1));
//         position.deploy(mockAsset, (loanAmount * currentValueRatio) / C.RATIO_FACTOR, "");

//         Agreement memory agreement;
//         agreement.loanAmount = loanAmount;
//         // agreement.factory.parameters =
//         agreement.position.addr = address(position);
//         agreement.deploymentTime = block.timestamp - timePassed;
//         console.log("deploymentTime: %s", agreement.deploymentTime);

//         StandardAssessor.Parameters memory parameters = StandardAssessor.Parameters({
//             asset: Asset({standard: ERC20_STANDARD, addr: C.WETH, decimals: 18, id: 0, data: ""}),
//             originationFeeRatio: originationFeeRatio,
//             interestRatio: interestRatio,
//             profitShareRatio: profitShareRatio
//         });
//         agreement.assessor = PluginReference({addr: address(assessorPlugin), parameters: abi.encode(parameters)});
//         (asset, cost) = assessorPlugin.getCost(agreement, position.getCloseAmount(agreement.position.parameters));
//     }

//     /// @notice manual defined test cases of getCost. Checks for correctness.
//     function test_GetCost() public {
//         uint256 loanAmount = 100e18;
//         uint256 timePassed = 24 * 60 * 60;

//         Asset memory asset;
//         uint256 cost;

//         (asset, cost) = getCost((10 * C.RATIO_FACTOR) / 100, 0, 0, loanAmount, 1, timePassed); // 10% origination fee
//         assertEq(cost, loanAmount / 10); // certainly going to have rounding error here
//         (asset, cost) = getCost(0, C.RATIO_FACTOR / 1_000_000, 0, loanAmount, 1, timePassed); // 0.0001% interest per second for 1 day
//         assertEq(cost, (loanAmount * timePassed) / 1_000_000); // rounding errors?
//         (asset, cost) = getCost(0, 0, (5 * C.RATIO_FACTOR) / 100, loanAmount, (120 * C.RATIO_FACTOR) / 100, timePassed); // 5% of 20% profit
//         assertEq(cost, (loanAmount * 20 * 5) / 100 / 100); // rounding errors?
//         (asset, cost) = getCost(0, 0, (5 * C.RATIO_FACTOR) / 100, loanAmount, (90 * C.RATIO_FACTOR) / 100, timePassed); // 5% of 10% loss
//         assertEq(cost, 0);
//         assertEq(asset.standard, ERC20_STANDARD);
//     }

//     /// @notice fuzz testing of getCost. Does not check for correctness.
//     function testFuzz_GetCost(
//         uint256 originationFeeRatio,
//         uint256 interestRatio,
//         uint256 profitShareRatio,
//         uint256 loanAmount,
//         uint256 currentValueRatio,
//         uint256 timePassed,
//         uint256 scaleUpRatio
//     ) public {
//         originationFeeRatio = bound(originationFeeRatio, 0, C.RATIO_FACTOR);
//         interestRatio = bound(interestRatio, 0, C.RATIO_FACTOR);
//         profitShareRatio = bound(profitShareRatio, 0, C.RATIO_FACTOR);
//         loanAmount = bound(loanAmount, 0, type(uint64).max);
//         currentValueRatio = bound(currentValueRatio, 0, 3 * C.RATIO_FACTOR);
//         timePassed = bound(timePassed, 0, 365 * 24 * 60 * 60);
//         (, uint256 cost) = getCost(
//             originationFeeRatio,
//             interestRatio,
//             profitShareRatio,
//             loanAmount,
//             currentValueRatio,
//             timePassed
//         );
//         uint256 currentValue = (loanAmount * currentValueRatio) / C.RATIO_FACTOR;

//         {
//             // assertLe(cost, loanAmount); // May not be true if cost parameters v high.
//             uint256 originationFee = (loanAmount * originationFeeRatio) / C.RATIO_FACTOR;
//             assertGe(cost, originationFee);
//             uint256 interest = (loanAmount * timePassed * interestRatio) / C.RATIO_FACTOR;
//             assertGe(cost, interest);
//             uint256 nonProfitCost = loanAmount + originationFee + interest;
//             if (currentValue > nonProfitCost) {
//                 uint256 profitShare = ((currentValue - nonProfitCost) * profitShareRatio) / C.RATIO_FACTOR;
//                 assertGe(cost, profitShare);
//             }
//         }

//         {
//             scaleUpRatio = bound(scaleUpRatio, 0, C.RATIO_FACTOR) + C.RATIO_FACTOR;
//             uint256 loanAmountBig = (loanAmount * scaleUpRatio) / C.RATIO_FACTOR;
//             uint256 timePassedBig = (timePassed * scaleUpRatio) / C.RATIO_FACTOR;
//             (, uint256 newCost) = getCost(
//                 originationFeeRatio,
//                 interestRatio,
//                 profitShareRatio,
//                 loanAmountBig,
//                 currentValueRatio,
//                 timePassed
//             );
//             assertLe(cost, newCost);
//             (, newCost) = getCost(
//                 originationFeeRatio,
//                 interestRatio,
//                 profitShareRatio,
//                 loanAmount,
//                 currentValueRatio,
//                 timePassedBig
//             );
//             assertLe(cost, newCost);
//         }
//     }
// }
