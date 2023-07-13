// SPDX-License-Identifier: MIT
// solhint-disable

pragma solidity 0.8.19;

/**
 * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
 * comprehensive as each unique implementation will likely need its own unique tests.
 */

import "@forge-std/Test.sol";
import "@forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Blueprint, SignedBlueprint, Tractor} from "@tractor/Tractor.sol";

import {SoloAccount} from "src/plugins/account/implementations/SoloAccount.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {IBookkeeper} from "src/interfaces/IBookkeeper.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {ILiquidator} from "src/interfaces/ILiquidator.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {StandardAssessor} from "src/plugins/assessor/implementations/StandardAssessor.sol";
import {InstantCloseTakeCollateral} from "src/plugins/liquidator/implementations/InstantCloseTakeCollateral.sol";
import {UniV3Oracle} from "src/plugins/oracle/implementations/UniV3Oracle.sol";
import {StaticOracle} from "src/plugins/oracle/implementations/StaticOracle.sol";
import {UniV3HoldFactory} from "src/plugins/position/implementations/UniV3Hold.sol";
import {WalletFactory} from "src/plugins/position/implementations/Wallet.sol";

import {Bookkeeper} from "src/Bookkeeper.sol";
import {IndexPair, PluginReference, BorrowerConfig, Order, Fill, Agreement} from "src/libraries/LibBookkeeper.sol";

import {TestUtils} from "test/TestUtils.sol";

import "src/libraries/C.sol";
import "src/libraries/LibUtils.sol";

contract EndToEndTest is TestUtils {
    IBookkeeper public bookkeeper;
    IAccount public accountPlugin;
    IAssessor public assessorPlugin;
    ILiquidator public liquidatorPlugin;
    IOracle public uniOraclePlugin;
    IOracle public staticOracle;
    IPosition public uniV3HoldFactory;
    IPosition public walletFactory;

    // Mirrors OZ EIP712 impl.
    bytes32 SIG_DOMAIN_SEPARATOR;

    address PEPE = 0x6982508145454Ce325dDbE47a25d4ec3d2311933; // cardinality too low and i don't want to pay
    address SHIB = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE; // WETH:SHIB 0.3% pool 0x2F62f2B4c5fcd7570a709DeC05D68EA19c82A9ec

    // Asset ETH_ASSET = Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""});
    Asset WETH_ASSET = Asset({standard: ERC20_STANDARD, addr: C.WETH, decimals: 18, id: 0, data: ""});
    Asset USDC_ASSET = Asset({standard: ERC20_STANDARD, addr: C.USDC, decimals: C.USDC_DECIMALS, id: 0, data: ""});

    uint256 LENDER_PRIVATE_KEY = 111;
    uint256 BORROWER_PRIVATE_KEY = 222;
    uint256 LIQUIDATOR_PRIVATE_KEY = 333;
    Asset[] ASSETS;

    constructor() {
        // ASSETS.push(Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""})); // Tests expect 0 index to be ETH
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.WETH, decimals: 18, id: 0, data: ""})); // Tests expect 0 index to be WETH
        ASSETS.push(Asset({standard: ERC20_STANDARD, addr: C.USDC, decimals: C.USDC_DECIMALS, id: 0, data: ""})); // Tests expect 1 index to be an ERC20
    }

    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl("mainnet"), 17186176);
        // vm.createSelectFork(vm.rpcUrl("goerli"), ); // NOTE ensure this is more recent than deployments.
        // vm.createSelectFork(vm.rpcUrl("sepolia"), 3784874); // NOTE ensure this is more recent than deployments.

        // // For local deploy of contracts latest local changes.
        bookkeeper = IBookkeeper(address(new Bookkeeper()));
        accountPlugin = IAccount(address(new SoloAccount(address(bookkeeper))));
        assessorPlugin = IAssessor(address(new StandardAssessor()));
        liquidatorPlugin = ILiquidator(address(new InstantCloseTakeCollateral(address(bookkeeper))));
        staticOracle = IOracle(address(new StaticOracle()));
        walletFactory = IPosition(address(new WalletFactory(address(bookkeeper))));
        // uniOraclePlugin = IOracle(address(new UniV3Oracle()));
        // uniV3HoldFactory = IPosition(address(new UniV3HoldFactory(address(bookkeeper))));

        // For use with pre deployed contracts.
        // bookkeeper = IBookkeeper();
        // accountPlugin = IAccount();
        // assessorPlugin = IAssessor();
        // liquidatorPlugin = ILiquidator();
        // staticOracle = IOracle(); // static price
        // walletFactory = IPosition();
        // uniOraclePlugin = IOracle(); // static prices
        // uniV3HoldFactory = IPosition();
    }

    // Using USDC as collateral, borrow ETH and trade it into a leveraged long PEPE position.
    function test_FillClose() public {
        address lender = vm.addr(LENDER_PRIVATE_KEY);
        address borrower = vm.addr(BORROWER_PRIVATE_KEY);

        SoloAccount.Parameters memory lenderAccountParams = SoloAccount.Parameters({owner: lender, salt: bytes32(0)});
        SoloAccount.Parameters memory borrowerAccountParams = SoloAccount.Parameters({
            owner: borrower,
            salt: bytes32(0)
        });

        fundAccount(lenderAccountParams);
        fundAccount(borrowerAccountParams);

        assertEq(accountPlugin.getBalance(WETH_ASSET, abi.encode(lenderAccountParams)), 10e18);
        assertEq(
            accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)),
            5_000 * (10 ** C.USDC_DECIMALS)
        );

        Order memory order = createOrder(lenderAccountParams);
        bytes memory packedData;
        packedData = bookkeeper.packDataField(bytes1(uint8(Bookkeeper.BlueprintDataType.ORDER)), abi.encode(order));
        // console.log("packedData:");
        // console.logBytes(packedData);
        Blueprint memory orderBlueprint = Blueprint({
            publisher: lender,
            data: packedData,
            maxNonce: type(uint256).max,
            startTime: 0,
            endTime: type(uint256).max
        });

        // console.log("blueprint data at encoding:");
        // console.logBytes(orderBlueprint.data);
        SignedBlueprint memory orderSignedBlueprint = createSignedBlueprint(orderBlueprint, LENDER_PRIVATE_KEY);

        Fill memory fill = createFill(borrowerAccountParams);
        vm.prank(borrower);
        bookkeeper.fillOrder(fill, orderSignedBlueprint);

        assertEq(accountPlugin.getBalance(WETH_ASSET, abi.encode(lenderAccountParams)), 8e18);
        assertLt(
            accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)),
            5_000 * (10 ** C.USDC_DECIMALS)
        );
        assertGt(accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)), 0);

        (SignedBlueprint memory agreementSignedBlueprint, Agreement memory agreement) = retrieveAgreementFromLogs();

        // Move time and block forward arbitrarily.
        vm.warp(block.timestamp + 5 days);
        vm.roll(block.number + (5 days / 12));

        // Borrower exits position. Send cost in eth because on local fork no value of assets occurs but cost increases.
        // uint256 cost = IAssessor(agreement.assessor.addr).getCost(agreement);
        // uint256 exitAmount = IPosition(agreement.position.addr).getCloseAmount(agreement.loanAsset, agreement.position.parameters);
        // console.log("exitAmount: %s", exitAmount);

        // Approve position to use funds to fulfil obligation to lender. Borrower loses money :(
        wethDeal(borrower, 12e18);
        deal(USDC_ASSET.addr, borrower, 5_000 * (10 ** C.USDC_DECIMALS), true);
        vm.prank(borrower);
        IERC20(C.USDC).approve(agreement.position.addr, 5_000 * (10 ** C.USDC_DECIMALS));
        vm.prank(borrower);
        IERC20(C.WETH).approve(agreement.position.addr, 12e18);
        vm.prank(borrower);
        bookkeeper.exitPosition(agreementSignedBlueprint);

        assertGe(
            accountPlugin.getBalance(WETH_ASSET, abi.encode(lenderAccountParams)),
            10e18,
            "lender act funds missing"
        );
        assertEq(
            accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)),
            5000 * (10 ** C.USDC_DECIMALS),
            "borrow act funds missing"
        );

        console.log("done");
    }

    // Using USDC as collateral, borrow ETH and trade it into a leveraged long position. Liquidate.
    function test_FillLiquidate() public {
        address lender = vm.addr(LENDER_PRIVATE_KEY);
        address borrower = vm.addr(BORROWER_PRIVATE_KEY);
        address liquidator = vm.addr(LIQUIDATOR_PRIVATE_KEY);

        SoloAccount.Parameters memory lenderAccountParams = SoloAccount.Parameters({owner: lender, salt: bytes32(0)});
        SoloAccount.Parameters memory borrowerAccountParams = SoloAccount.Parameters({
            owner: borrower,
            salt: bytes32(0)
        });

        fundAccount(lenderAccountParams);
        fundAccount(borrowerAccountParams);

        assertEq(accountPlugin.getBalance(WETH_ASSET, abi.encode(lenderAccountParams)), 10e18);
        assertEq(
            accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)),
            5_000 * (10 ** C.USDC_DECIMALS)
        );

        Order memory order = createOrder(lenderAccountParams);
        Blueprint memory orderBlueprint = Blueprint({
            publisher: lender,
            data: bookkeeper.packDataField(bytes1(uint8(Bookkeeper.BlueprintDataType.ORDER)), abi.encode(order)),
            maxNonce: type(uint256).max,
            startTime: 0,
            endTime: type(uint256).max
        });

        // console.log("blueprint data at encoding:");
        // console.logBytes(orderBlueprint.data);
        SignedBlueprint memory orderSignedBlueprint = createSignedBlueprint(orderBlueprint, LENDER_PRIVATE_KEY);

        Fill memory fill = createFill(borrowerAccountParams);
        vm.prank(borrower);
        bookkeeper.fillOrder(fill, orderSignedBlueprint);

        assertEq(accountPlugin.getBalance(WETH_ASSET, abi.encode(lenderAccountParams)), 8e18);
        assertLt(
            accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)),
            5_000 * (10 ** C.USDC_DECIMALS)
        );
        assertGt(accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)), 0);

        (SignedBlueprint memory agreementSignedBlueprint, Agreement memory agreement) = retrieveAgreementFromLogs();

        // Move time and block forward arbitrarily.
        vm.warp(block.timestamp + 8 days);
        vm.roll(block.number + (8 days / 12));

        // Borrower exits position. Send cost in eth because on local fork no value of assets occurs but cost increases.
        // uint256 cost = IAssessor(agreement.assessor.addr).getCost(agreement);
        // uint256 exitAmount = IPosition(agreement.position.addr).getCloseAmount(agreement.loanAsset, agreement.position.parameters);
        // console.log("exitAmount: %s", exitAmount);

        // Approve position to use funds to fulfil obligation to lender. Borrower loses money :(
        vm.deal(liquidator, 2e18);
        wethDeal(liquidator, 12e18);
        // deal(USDC_ASSET.addr, liquidator, 5_000 * (10 ** C.USDC_DECIMALS), true);
        // vm.prank(liquidator);
        // IERC20(C.USDC).approve(address(liquidatorPlugin), 5_000 * (10 ** C.USDC_DECIMALS));
        // NOTE that the liquidator has to approve the position to spend their assets. meaning liquidators likely will not be willing to liquidate unverified positions.
        vm.prank(liquidator);
        IERC20(C.WETH).approve(address(agreement.position.addr), 12e18); // exact amount determined from prev runs
        vm.prank(liquidator);
        bookkeeper.kick(agreementSignedBlueprint);

        assertGe(accountPlugin.getBalance(WETH_ASSET, abi.encode(lenderAccountParams)), 10e18);
        assertLt(
            accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)),
            5_000 * (10 ** C.USDC_DECIMALS)
        );
        assertGt(IERC20(USDC_ASSET.addr).balanceOf(liquidator), 0);

        console.log("done");
    }

    function fundAccount(SoloAccount.Parameters memory accountParams) private {
        vm.deal(accountParams.owner, 2e18);
        wethDeal(accountParams.owner, 12e18);
        deal(USDC_ASSET.addr, accountParams.owner, 5_000 * (10 ** C.USDC_DECIMALS), true);

        vm.startPrank(accountParams.owner);
        IERC20(C.WETH).approve(address(accountPlugin), 10e18);
        accountPlugin.loadFromUser(WETH_ASSET, 10e18, abi.encode(accountParams));
        IERC20(C.USDC).approve(address(accountPlugin), 5_000 * (10 ** C.USDC_DECIMALS));
        accountPlugin.loadFromUser(USDC_ASSET, 5_000 * (10 ** C.USDC_DECIMALS), abi.encode(accountParams));
        vm.stopPrank();
    }

    function createOrder(SoloAccount.Parameters memory accountParams) private view returns (Order memory) {
        // Set individual structs here for cleanliness and solidity ease.
        PluginReference memory account = PluginReference({
            addr: address(accountPlugin),
            parameters: abi.encode(accountParams)
        });
        // Solidity array syntax is so bad D:
        address[] memory fillers = new address[](0);
        uint256[] memory minLoanAmounts = new uint256[](2);
        minLoanAmounts[0] = 1e18;
        minLoanAmounts[1] = 1000 * (10 ** C.USDC_DECIMALS);
        Asset[] memory loanAssets = new Asset[](1);
        loanAssets[0] = WETH_ASSET;
        Asset[] memory collAssets = new Asset[](1);
        collAssets[0] = USDC_ASSET;
        PluginReference[] memory loanOracles = new PluginReference[](1);
        // loanOracles[0] = PluginReference({
        //     addr: address(uniOraclePlugin),
        //     parameters: abi.encode(
        //         UniV3Oracle.Parameters({
        //             pathFromEth: abi.encodePacked(C.USDC, uint24(500), C.WETH),
        //             pathToEth: abi.encodePacked(C.WETH, uint24(500), C.USDC),
        //             twapTime: 300
        //         })
        //         )
        // });
        loanOracles[0] = PluginReference({
            addr: address(staticOracle),
            parameters: abi.encode(StaticOracle.Parameters({ratio: 1 * (10 ** C.ETH_DECIMALS)}))
        });
        console.log(
            "eth value of 1000 eth: %s",
            staticOracle.getSpotValue(1000 * (10 ** C.ETH_DECIMALS), loanOracles[0].parameters)
        );
        console.log(
            "eth amount for 60 eth: %s",
            IOracle(loanOracles[0].addr).getResistantAmount(60 * (10 ** C.ETH_DECIMALS), loanOracles[0].parameters)
        );

        PluginReference[] memory collOracles = new PluginReference[](1);
        collOracles[0] = PluginReference({
            addr: address(staticOracle),
            parameters: abi.encode(StaticOracle.Parameters({ratio: 2000 * (10 ** C.USDC_DECIMALS)}))
        });
        console.log(
            "eth value of 1000 usdc: %s",
            staticOracle.getSpotValue(1000 * (10 ** C.USDC_DECIMALS), collOracles[0].parameters)
        );
        console.log(
            "usdc amount for 60 eth: %s",
            IOracle(loanOracles[0].addr).getResistantAmount(60 * (10 ** C.ETH_DECIMALS), collOracles[0].parameters)
        );
        address[] memory factories = new address[](1);
        // factories[0] = address(uniV3HoldFactory);
        factories[0] = address(walletFactory);

        PluginReference memory assessor = PluginReference({
            addr: address(assessorPlugin),
            parameters: abi.encode(
                StandardAssessor.Parameters({
                    asset: loanAssets[0],
                    originationFeeRatio: C.RATIO_FACTOR / 100,
                    interestRatio: C.RATIO_FACTOR / 1000000000,
                    profitShareRatio: C.RATIO_FACTOR / 20
                })
            )
        });
        PluginReference memory liquidator = PluginReference({addr: address(liquidatorPlugin), parameters: ""});

        // Lender creates an offer.
        return
            Order({
                minLoanAmounts: minLoanAmounts,
                loanAssets: loanAssets,
                collAssets: collAssets,
                fillers: fillers,
                maxDuration: 7 days,
                minCollateralRatio: C.RATIO_FACTOR / 5,
                account: account,
                assessor: assessor,
                liquidator: liquidator,
                /* Allowlisted variables */
                loanOracles: loanOracles,
                collOracles: collOracles,
                // Lender would need to list parameters for all possible holdable tokens from all possible lent tokens. Instead just allow a whole factory.
                factories: factories,
                isOffer: true,
                borrowerConfig: BorrowerConfig(0, "")
            });
    }

    function createFill(SoloAccount.Parameters memory borrowerAccountParams) private view returns (Fill memory) {
        // BorrowerConfig memory borrowerConfig = BorrowerConfig({
        //     initCollateralRatio: C.RATIO_FACTOR / 2,
        //     positionParameters: abi.encode(
        //         UniV3HoldFactory.Parameters({
        //             enterPath: abi.encodePacked(C.WETH, uint24(3000), SHIB),
        //             exitPath: abi.encodePacked(SHIB, uint24(3000), C.WETH)
        //         })
        //     )
        // });
        BorrowerConfig memory borrowerConfig = BorrowerConfig({
            initCollateralRatio: (C.RATIO_FACTOR * 11) / 10, // 110%
            positionParameters: abi.encode(WalletFactory.Parameters({recipient: borrowerAccountParams.owner}))
        });

        return
            Fill({
                account: PluginReference({addr: address(accountPlugin), parameters: abi.encode(borrowerAccountParams)}),
                loanAmount: 2e18, // must be valid with init CR and available collateral value
                takerIdx: 0,
                loanAssetIdx: 0,
                collAssetIdx: 0,
                loanOracleIdx: 0,
                collOracleIdx: 0,
                factoryIdx: 0,
                isOfferFill: true,
                borrowerConfig: borrowerConfig
            });
    }

    function createSignedBlueprint(
        Blueprint memory blueprint,
        uint256 privateKey
    ) private view returns (SignedBlueprint memory) {
        bytes32 blueprintHash = bookkeeper.getBlueprintHash(blueprint);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, blueprintHash);

        // console.log("blueprint raw hash: ");
        // console.logBytes32(keccak256(abi.encode(blueprint)));
        // console.log("blueprint full hash: ");
        // console.logBytes32(blueprintHash);
        // console.log("signature: ");
        // console.logBytes(abi.encodePacked(r, s, v));

        return
            SignedBlueprint({blueprint: blueprint, blueprintHash: blueprintHash, signature: abi.encodePacked(r, s, v)});
    }

    /// @dev assumes one agreement in getRecordedLogs. idk if gets oldest or newest.
    function retrieveAgreementFromLogs()
        private
        returns (SignedBlueprint memory agreementSignedBlueprint, Agreement memory agreement)
    {
        // At this point the position is live. Things are happening and money is being made, hopefully. The agreement
        // was defined in the Bookkeeper contract and emitted as an event.
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // = abi.decode(entries[entries.length - 1].data, (SignedBlueprint));

        // Extract signed agreement from logs.
        for (uint256 i; i < entries.length; i++) {
            // hardcoded event sig for OrderFilled (from brownie console)
            if (entries[i].topics[0] == 0x21a6001862375a91bbf0eff278ae1eaee77323f67273ed674a16f9607888696f) {
                // console.log("entry data:");
                // console.logBytes(entries[i].data);
                agreementSignedBlueprint = abi.decode(entries[i].data, (SignedBlueprint)); // signed blueprint is only thing in data
            }
        }
        require(agreementSignedBlueprint.blueprintHash != 0x0, "failed to find agreement in logs");
        (, bytes memory data) = bookkeeper.unpackDataField(agreementSignedBlueprint.blueprint.data);
        agreement = abi.decode(data, (Agreement));
    }
}
