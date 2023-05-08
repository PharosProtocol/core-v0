// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
 * comprehensive as each unique implementation will likely need its own unique tests.
 */

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {IUniswapV3Pool} from "lib/v3-core/contracts/UniswapV3Pool.sol";

import {DoubleSidedAccount} from "src/modules/account/implementations/DoubleSidedAccount.sol";
import {StandardAssessor} from "src/modules/assessor/implementations/StandardAssessor.sol";
import {InstantLiquidator} from "src/modules/liquidator/implementations/InstantLiquidator.sol";
import {UniswapV3Oracle} from "src/modules/oracle/implementations/UniswapV3Oracle.sol";
import {StaticUsdcPriceOracle} from "src/modules/oracle/implementations/StaticValue.sol";
import {UniV3HoldTerminal} from "src/terminal/implementations/UniV3Hold.sol";

import {Bookkeeper} from "src/bookkeeper/Bookkeeper.sol";
import {IndexPair, ModuleReference, BorrowerConfig, Order, Fill, Agreement} from "src/bookkeeper/LibBookkeeper.sol";

import "src/C.sol";
import "src/LibUtil.sol";
import {Blueprint, SignedBlueprint, Tractor} from "lib/tractor/Tractor.sol";

contract EndToEndTest is Test {
    Bookkeeper public bookkeeper;
    DoubleSidedAccount public accountModule;
    StandardAssessor public assessorModule;
    InstantLiquidator public liquidatorModule;
    UniswapV3Oracle public uniOracleModule;
    StaticUsdcPriceOracle public staticUsdcPriceOracle;
    UniV3HoldTerminal public terminal;

    // Mirrors OZ EIP712 impl.
    bytes32 SIG_DOMAIN_SEPARATOR;

    address PEPE = 0x6982508145454Ce325dDbE47a25d4ec3d2311933; // cardinality too low and i don't want to pay (~$30 at gas cost of 30)
    address SHIB = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE; // WETH:SHIB 0.3% pool 0x2F62f2B4c5fcd7570a709DeC05D68EA19c82A9ec

    Asset ETH_ASSET = Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""});
    Asset USDC_ASSET = Asset({standard: ERC20_STANDARD, addr: C.USDC, id: 0, data: ""});

    uint256 LENDER_PRIVATE_KEY = 111;
    uint256 BORROWER_PRIVATE_KEY = 222;

    // Copy of event definitions.
    event AssetAdded(address owner, bytes32 salt, Asset asset, uint256 amount);
    event AssetRemoved(address owner, bytes32 salt, Asset asset, uint256 amount);

    constructor() {}

    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl("mainnet"), 17186176);

        // Deploy Bookkeeper and module contracts.
        bookkeeper = new Bookkeeper();
        accountModule = new DoubleSidedAccount(address(bookkeeper));
        assessorModule = new StandardAssessor();
        liquidatorModule = new InstantLiquidator();
        uniOracleModule = new UniswapV3Oracle();
        staticUsdcPriceOracle = new StaticUsdcPriceOracle();
        terminal = new UniV3HoldTerminal(address(bookkeeper));
    }

    // Using USDC as collateral, borrow ETH and trade it into a leveraged long PEPE position.
    function testUnit_Agree() public {
        address lender = vm.addr(LENDER_PRIVATE_KEY);
        address borrower = vm.addr(BORROWER_PRIVATE_KEY);

        // Lender creates and funds account with ETH.
        vm.deal(lender, 10e18);
        DoubleSidedAccount.Parameters memory lenderAccountParams =
            DoubleSidedAccount.Parameters({owner: lender, salt: bytes32(0)});
        vm.prank(lender);
        accountModule.load{value: 10e18}(ETH_ASSET, 10e18, abi.encode(lenderAccountParams));

        // Borrower creates and funds account with USDC.
        deal(USDC_ASSET.addr, borrower, 5_000e6, true);
        DoubleSidedAccount.Parameters memory borrowerAccountParams =
            DoubleSidedAccount.Parameters({owner: borrower, salt: bytes32(0)});
        vm.prank(borrower);
        IERC20(C.USDC).approve(address(accountModule), 5_000e6);
        vm.prank(borrower);
        accountModule.load(USDC_ASSET, 5_000e6, abi.encode(borrowerAccountParams));

        Order memory offer;
        {
            // Set individual structs here for cleanliness and solidity ease.
            ModuleReference memory account =
                ModuleReference({addr: address(accountModule), parameters: abi.encode(lenderAccountParams)});
            ModuleReference memory assessor = ModuleReference({
                addr: address(assessorModule),
                parameters: abi.encode(
                    StandardAssessor.Parameters({
                        originationFeeRatio: C.RATIO_FACTOR / 100,
                        interestRatio: C.RATIO_FACTOR / 1000000,
                        profitShareRatio: C.RATIO_FACTOR / 20
                    })
                    )
            });
            ModuleReference memory liquidator =
                ModuleReference({addr: address(liquidatorModule), parameters: abi.encode(0)});
            // Solidity array syntax is so bad D:
            uint256[] memory minLoanAmounts = new uint256[](1);
            minLoanAmounts[0] = 1e18;
            Asset[] memory loanAssets = new Asset[](1);
            loanAssets[0] = ETH_ASSET;
            Asset[] memory collateralAssets = new Asset[](1);
            collateralAssets[0] = USDC_ASSET;
            address[] memory takers = new address[](0);
            ModuleReference[] memory loanOracles = new ModuleReference[](1);
            loanOracles[0] = ModuleReference({
                addr: address(uniOracleModule),
                parameters: abi.encode(
                    UniswapV3Oracle.Parameters({
                        pathFromUsd: abi.encodePacked(C.USDC, uint24(500), C.WETH),
                        pathToUsd: abi.encodePacked(C.WETH, uint24(500), C.USDC),
                        stepSlippageRatio: C.RATIO_FACTOR / 1000,
                        twapTime: 300
                    })
                    )
            });
            ModuleReference[] memory collateralOracles = new ModuleReference[](1);
            collateralOracles[0] = ModuleReference({
                addr: address(staticUsdcPriceOracle),
                parameters: abi.encode(StaticUsdcPriceOracle.Parameters({value: 1000000}))
            });
            address[] memory terminals = new address[](1);
            terminals[0] = address(terminal);

            // Lender creates an offer.
            offer = Order({
                minLoanAmounts: minLoanAmounts,
                loanAssets: loanAssets,
                collateralAssets: collateralAssets,
                takers: takers,
                maxDuration: 7 days,
                minCollateralRatio: C.RATIO_FACTOR / 5,
                account: account,
                assessor: assessor,
                liquidator: liquidator,
                /* Allowlisted variables */
                loanOracles: loanOracles,
                collateralOracles: collateralOracles,
                // Lender would need to list parameters for all possible holdable tokens from all possible lent tokens. Instead just allow a whole terminal.
                terminals: terminals,
                isOffer: true,
                borrowerConfig: BorrowerConfig(0, "")
            });
        }
        Blueprint memory offerBlueprint = Blueprint({
            publisher: lender,
            data: bookkeeper.packDataField(bytes1(uint8(Bookkeeper.BlueprintDataType.ORDER)), abi.encode(offer)),
            maxNonce: type(uint256).max,
            startTime: 0,
            endTime: type(uint256).max
        });
        // console.log("offer data at encoding:");
        // console.logBytes(abi.encode(offer));
        // console.log("blueprint data at encoding:");
        // console.logBytes(offerBlueprint.data);
        bytes32 offerBlueprintHash = bookkeeper.getTypedDataHash(keccak256(abi.encode(offerBlueprint)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(LENDER_PRIVATE_KEY, offerBlueprintHash);
        SignedBlueprint memory offerSignedBlueprint = SignedBlueprint({
            blueprint: offerBlueprint,
            blueprintHash: offerBlueprintHash,
            signature: abi.encodePacked(r, s, v)
        });

        // Borrower fills offer.
        Fill memory fill;

        {
            BorrowerConfig memory borrowerConfig = BorrowerConfig({
                initCollateralRatio: C.RATIO_FACTOR / 3,
                positionParameters: abi.encode(
                    UniV3HoldTerminal.Parameters({
                        enterPath: abi.encodePacked(C.WETH, uint24(3000), SHIB),
                        exitPath: abi.encodePacked(SHIB, uint24(3000), C.WETH)
                    })
                    )
            });

            fill = Fill({
                loanAmount: 2e18, // must be valid with init CR and available collateral value
                takerIdx: 0,
                loanAssetIdx: 0,
                collateralAssetIdx: 0,
                loanOracleIdx: 0,
                collateralOracleIdx: 0,
                terminalIdx: 0,
                isOfferFill: true,
                borrowerConfig: borrowerConfig
            });
        }
        ModuleReference memory borrowerAccount =
            ModuleReference({addr: address(accountModule), parameters: abi.encode(borrowerAccountParams)});
        vm.prank(borrower);
        bookkeeper.fillOrder(fill, offerSignedBlueprint, borrowerAccount);

        // console.log("gas left: %s", gasleft());
        // IUniswapV3Pool(0x11950d141EcB863F01007AdD7D1A342041227b58).increaseObservationCardinalityNext(25);
        // console.log("gas left: %s", gasleft());

        // At this point the position is live. Things are happening and money is being made, hopefully. The agreement
        // was defined in the Bookkeeper contract and emitted as an event.
        Vm.Log[] memory entries = vm.getRecordedLogs();
        SignedBlueprint memory agreementSignedBlueprint; // = abi.decode(entries[entries.length - 1].data, (SignedBlueprint));

        // Extract signed agreement from logs.
        for (uint256 i; i < entries.length; i++) {
            // hardcoded event sig for OrderFilled (from brownie console)
            if (entries[i].topics[0] == 0x471ac8b1a049c99d4b6c211ae01f28ddacb8daefce60910d97c273627db7d4cd) {
                console.log("entry data:");
                console.logBytes(entries[i].data);
                agreementSignedBlueprint = abi.decode(entries[i].data, (SignedBlueprint)); // signed blueprint is only thing in data
            }
        }

        // Move time and block forward arbitrarily.
        vm.warp(block.timestamp + 100 * 12);
        vm.roll(block.number + 100);

        // // Borrower exits position.
        // vm.prank(borrower);
        // bookkeeper.exitPosition(agreementSignedBlueprint);

        console.log("done");
    }
}
