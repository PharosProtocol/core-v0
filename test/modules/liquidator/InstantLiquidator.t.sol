// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
 * comprehensive as each unique implementation will likely need its own unique tests.
 */

import "forge-std/Test.sol";
import {HandlerUtils} from "test/TestUtils.sol";
import {TestUtils} from "test/TestUtils.sol";

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

import {IAccount} from "src/interfaces/IAccount.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {ILiquidator} from "src/interfaces/ILiquidator.sol";
import {C} from "src/libraries/C.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset, ERC20_STANDARD} from "src/libraries/LibUtils.sol";
import {SoloAccount} from "src/modules/account/implementations/SoloAccount.sol";
import {InstantCloseTakeCollateral} from "src/modules/liquidator/implementations/InstantCloseTakeCollateral.sol";
import {MockAssessor} from "test/mocks/MockAssessor.sol";
import {MockPosition} from "test/mocks/MockPosition.sol";

contract InstantLiquidatorTest is TestUtils {
    // Bookkeeper public bookkeeper;
    IAssessor public assessorModule;
    IAccount public accountModule;
    ILiquidator public liquidatorModule;

    address bookkeeperAddr = address(1);
    Asset[] ASSETS;

    constructor() {
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.WETH, decimals: 18, id: 0, data: ""})); // Tests expect 0 index to be WETH
        // NOTE why is USDC breaking? And why does USDC look like it is using a proxy wrapper contract...?
        // ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.USDC, decimals: C.USDC_DECIMALS, id: 0, data: ""})); // Tests expect 1 index to be an ERC20}
    }

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl("mainnet"), 17092863);

        SoloAccount accountContract = new SoloAccount(bookkeeperAddr);
        accountModule = IAccount(accountContract);

        InstantCloseTakeCollateral liquidatorContract = new InstantCloseTakeCollateral(bookkeeperAddr);
        liquidatorModule = ILiquidator(liquidatorContract);
    }

    // NOTE it is unclear if this should be a fuzz or a direct unit tests. Are fuzzes handled by invariant tests?
    function test_InstantCloseTakeCollateralKick(
        uint256 loanAssetIdx,
        uint256 collAssetIdx,
        uint256 loanAmount,
        uint256 collAmount,
        uint256 positionDelta,
        bool positionProfitable,
        uint256 cost
    ) public {
        vm.assume(msg.sender != bookkeeperAddr);

        // SECURITY NOTE what are the testing value implications of assuming these numbers are not too large? This
        //      assumption simplifies testing by avoiding overflows.
        loanAssetIdx = bound(loanAssetIdx, 0, ASSETS.length - 1);
        collAssetIdx = bound(collAssetIdx, 0, ASSETS.length - 1);
        loanAmount = bound(loanAmount, 0, type(uint128).max);
        collAmount = bound(collAmount, 0, type(uint128).max);
        positionDelta = bound(positionDelta, 0, loanAmount);
        cost = bound(cost, 0, type(uint128).max);

        uint256 positionAmount;
        if (positionProfitable) {
            positionAmount = loanAmount + positionDelta;
        } else {
            positionAmount = loanAmount - positionDelta;
        }

        // string memory revertMsg =
        //     string.concat("AccessControl: account ", Strings.toHexString(uint160(address(this)), 20));
        // revertMsg = string.concat(revertMsg, " is missing role ");
        // revertMsg = string.concat(revertMsg, Strings.toHexString(uint256(C.ADMIN_ROLE), 32));

        // Set assessor and cost.
        MockAssessor assessorContract = new MockAssessor(ASSETS[loanAssetIdx], cost);
        assessorModule = IAssessor(assessorContract);

        // Set position and value.
        MockPosition positionFactory = new MockPosition(bookkeeperAddr);
        vm.prank(bookkeeperAddr);
        IPosition position = IPosition(positionFactory.createPosition());
        vm.prank(bookkeeperAddr);
        position.deploy(ASSETS[loanAssetIdx], positionAmount, "");

        // Create mock agreement and position.
        Agreement memory agreement;
        agreement.lenderAccount.addr = address(accountModule);
        agreement.lenderAccount.parameters = abi.encode(SoloAccount.Parameters({owner: address(2), salt: "salt"}));
        agreement.borrowerAccount.addr = address(accountModule);
        agreement.borrowerAccount.parameters = abi.encode(SoloAccount.Parameters({owner: address(3), salt: "salt"}));
        agreement.loanAsset = ASSETS[loanAssetIdx];
        agreement.loanAmount = loanAmount;
        agreement.collAsset = ASSETS[collAssetIdx];
        agreement.collAmount = collAmount;
        agreement.assessor.addr = address(assessorModule);
        agreement.position.addr = address(position);

        // Deal assets to position.
        dealErc20(agreement.loanAsset.addr, address(position), positionAmount);
        dealErc20(agreement.collAsset.addr, address(position), agreement.collAmount);

        // Deal excess cost to sender and approve position module to pull.
        if (loanAmount + cost > positionAmount) {
            dealErc20(agreement.loanAsset.addr, msg.sender, loanAmount + cost - positionAmount);
            vm.prank(msg.sender);
            IERC20(agreement.loanAsset.addr).approve(address(position), loanAmount + cost - positionAmount);
        }

        // Fail give control with non-bookkeeper caller.
        vm.expectRevert();
        position.transferContract(address(liquidatorModule));

        // Give control to liquidator.
        vm.prank(bookkeeperAddr);
        position.transferContract(address(liquidatorModule));

        // Fail kick with non-bookkeeper caller.
        vm.expectRevert();
        liquidatorModule.receiveKick(msg.sender, agreement);

        // Kick position.
        vm.prank(bookkeeperAddr);
        liquidatorModule.receiveKick(msg.sender, agreement);

        assertEq(
            IERC20(agreement.loanAsset.addr).balanceOf(agreement.position.addr),
            0,
            "position loan asset funds incorrect"
        );
        assertEq(
            IERC20(agreement.collAsset.addr).balanceOf(agreement.position.addr),
            0,
            "position collateral asset funds incorrect"
        );

        // Asset in expected locations.
        // 1. Liquidator: collateral asset, all collateral amount
        // 2. Lender: loan asset, loan amount + cost (excess of position amount comes from liquidator)
        // 3. Borrower: loan asset excess beyond loan amount and cost
        uint256 borrowerProfit;
        if (positionProfitable && positionDelta > cost) {
            borrowerProfit = positionDelta - cost;
        }
        assertEq(
            IERC20(agreement.collAsset.addr).balanceOf(msg.sender),
            agreement.collAmount,
            "liquidator sender funds incorrect"
        );
        assertEq(
            accountModule.getBalance(agreement.loanAsset, agreement.lenderAccount.parameters),
            agreement.loanAmount + cost,
            "Lender funds incorrect"
        );
        assertEq(
            accountModule.getBalance(agreement.loanAsset, agreement.borrowerAccount.parameters),
            borrowerProfit,
            "borrower funds incorrect"
        );
        // assertEq(
        //     accountModule.getBalance(agreement.loanAsset, agreement.borrowerAccount.parameters),
        //     loanAssetIdx != collAssetIdx ? borrowerProfit : borrowerProfit,
        //     "borrower funds incorrect"
        // );

        // Control of position is sender.
        assertTrue(position.hasRole(C.ADMIN_ROLE, msg.sender));
    }
}
