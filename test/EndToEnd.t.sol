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
import {StaticOracle} from "src/plugins/oracle/implementations/StaticOracle.sol";
import {ChainlinkOracle} from "src/plugins/oracle/implementations/ChainlinkOracle.sol";
import {BeanOracle} from "src/plugins/oracle/implementations/BeanOracle.sol";
import {WalletFactory} from "src/plugins/position/implementations/Wallet.sol";

import {Bookkeeper} from "src/Bookkeeper.sol";
import {IndexPair, PluginReference, BorrowerConfig, Order, Fill, Agreement} from "src/libraries/LibBookkeeper.sol";

import {TestUtils} from "test/TestUtils.sol";

import {C} from "src/libraries/C.sol";
import {TC} from "test/TC.sol";
import "src/libraries/LibUtils.sol";

contract EndToEndTest is TestUtils {
    IBookkeeper public bookkeeper;
    IAccount public accountPlugin;
    IAssessor public assessorPlugin;
    ILiquidator public liquidatorPlugin;
    IOracle public chainlinkOracle;
    IOracle public staticOracle;
    IOracle public beanOracle;
    IPosition public walletFactory;
    

    // Mirrors OZ EIP712 impl.
    bytes32 SIG_DOMAIN_SEPARATOR;

    address PEPE = 0x6982508145454Ce325dDbE47a25d4ec3d2311933; // cardinality too low and i don't want to pay
    address SHIB = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE; // WETH:SHIB 0.3% pool 0x2F62f2B4c5fcd7570a709DeC05D68EA19c82A9ec

    // Asset ETH_ASSET = Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""});
    bytes constant WETH_ASSET = abi.encode(Asset({addr: C.WETH, decimals: 18}));

    bytes constant USDC_ASSET = abi.encode(Asset({addr: TC.USDC, decimals: TC.USDC_DECIMALS}));
    
    Asset WETH_ASSETT = Asset({addr: C.WETH, decimals: 18});
    Asset USDC_ASSETT = Asset({addr: TC.USDC, decimals: TC.USDC_DECIMALS});

    uint256 LENDER_PRIVATE_KEY = 111;
    uint256 BORROWER_PRIVATE_KEY = 222;
    uint256 LIQUIDATOR_PRIVATE_KEY = 333;
    uint256 LOAN_AMOUNT = 1e17 ;
    Asset[] ASSETS;

    constructor() {
        // ASSETS.push(Asset({standard: ETH_STANDARD, addr: address(0), id: 0, data: ""})); // Tests expect 0 index to be ETH
        ASSETS.push(Asset({addr: C.WETH, decimals: 18})); // Tests expect 0 index to be WETH
        ASSETS.push(Asset({addr: TC.USDC, decimals: TC.USDC_DECIMALS})); // Tests expect 1 index to be an ERC20
    }

    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl(TC.CHAIN_NAME), TC.BLOCK_NUMBER); // NOTE ensure this is more recent than deployments.

        // For local deploy of contracts latest local changes.
        bookkeeper = IBookkeeper(address(new Bookkeeper()));
        accountPlugin = IAccount(address(new SoloAccount(address(bookkeeper))));
        assessorPlugin = IAssessor(address(new StandardAssessor()));
        staticOracle = IOracle(address(new StaticOracle()));
        walletFactory = IPosition(address(new WalletFactory(address(bookkeeper))));
        chainlinkOracle= IOracle(address(new ChainlinkOracle()));
        beanOracle= IOracle(address(new BeanOracle()));

        // // For use with pre deployed contracts.
        // bookkeeper = IBookkeeper(0x96DEA1646129fF9637CE5cCE81E65559af172b92);
        // accountPlugin = IAccount(0x225D9FaD9081F0E67dD5E4b93E26e85E8F70a9aE);
        // assessorPlugin = IAssessor(0x5F5baC1aEF241eB4CB0B484bF68d104B00E1F98E);
        // liquidatorPlugin = ILiquidator(0x1bdD37aFC33C59D0B1572b23B9188531d6aA7cda);
        // staticOracle = IOracle(0xeE3B0F63eB134a06833b72082362c0a1Ed80B717); // static price
        // walletFactory = IPosition(0x51b245b41037B966e8709B622Ee735a653e3d40d);
        // uniOraclePlugin = IOracle(); // static prices
        // uniV3HoldFactory = IPosition();
    }



    // Using USDC as collateral, borrow ETH with USDC.
    function test_FillClose() public {
        address lender = vm.addr(LENDER_PRIVATE_KEY);
        address borrower = vm.addr(BORROWER_PRIVATE_KEY);

        bytes memory addressETH = abi.encode(address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419));
        bytes memory addressBTC = abi.encode(address(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c));

        console.log("chainlink ETH",chainlinkOracle.getClosePrice(addressETH) );
        console.log("chainlink BTC",chainlinkOracle.getClosePrice(addressBTC) );



        SoloAccount.Parameters memory lenderAccountParams = SoloAccount.Parameters({owner: lender, salt: bytes32(0)});
        SoloAccount.Parameters memory borrowerAccountParams = SoloAccount.Parameters({
            owner: borrower,
            salt: bytes32(0)
        });

        fundAccount(lenderAccountParams);
        fundAccount(borrowerAccountParams);

        assertEq(accountPlugin.getBalance(WETH_ASSET, abi.encode(lenderAccountParams)), 12e18);
        assertEq(
            accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)),
            5_000 * (10 ** TC.USDC_DECIMALS)
        );
        console.log("borrower account",accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)) );

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
                
        assertEq(accountPlugin.getBalance(WETH_ASSET, abi.encode(lenderAccountParams)), 12e18 - LOAN_AMOUNT);
        assertLt(
            accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)),
            5_000 * (10 ** TC.USDC_DECIMALS)
        );
        assertGt(accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)), 0);

        (SignedBlueprint memory agreementSignedBlueprint, Agreement memory agreement) = retrieveAgreementFromLogs();

        // Move time and block forward arbitrarily.
        vm.warp(block.timestamp + 5 days);
        vm.roll(block.number + (5 days / 12));

        
        console.log("lender account", accountPlugin.getBalance(WETH_ASSET, abi.encode(lenderAccountParams)));
        console.log("borrower wallet",IERC20(USDC_ASSETT.addr).balanceOf(borrower));

// Approve position to use funds to fulfil obligation to lender. Borrower loses money :(
        wethDeal(borrower, 12e18);
        vm.prank(borrower);
        IERC20(TC.USDC).approve(agreement.position.addr, 5_000 * (10 ** TC.USDC_DECIMALS));
        vm.prank(borrower);
        IERC20(C.WETH).approve(agreement.position.addr, 12e18);
        vm.prank(borrower);
        bookkeeper.closePosition(agreementSignedBlueprint);
        console.log("closePosition");
        console.log("lender account", accountPlugin.getBalance(WETH_ASSET, abi.encode(lenderAccountParams)));
        console.log("borrower account",accountPlugin.getBalance(USDC_ASSET, abi.encode(borrowerAccountParams)) );
        console.log("borrower wallet",IERC20(USDC_ASSETT.addr).balanceOf(borrower));

    }


    function fundAccount(SoloAccount.Parameters memory accountParams) private {
        vm.deal(accountParams.owner, 2e18);
        wethDeal(accountParams.owner, 12e18);
        deal(USDC_ASSETT.addr, accountParams.owner, 5_000 * (10 ** TC.USDC_DECIMALS), true);

        vm.startPrank(accountParams.owner);
        IERC20(C.WETH).approve(address(accountPlugin), 12e18);
        accountPlugin.loadFromUser(WETH_ASSET, 12e18, abi.encode(accountParams));
        IERC20(TC.USDC).approve(address(accountPlugin), 5_000 * (10 ** TC.USDC_DECIMALS));
        accountPlugin.loadFromUser(USDC_ASSET, 5_000 * (10 ** TC.USDC_DECIMALS), abi.encode(accountParams));
        vm.stopPrank();
    }

    function createOrder(SoloAccount.Parameters memory accountParams) private view returns (Order memory) {
        // Set individual structs here for cleanliness and solidity ease.
        PluginReference memory account = PluginReference({
            addr: address(accountPlugin),
            parameters: abi.encode(accountParams)
        });

        address[] memory fillers = new address[](0);
        uint256[] memory minLoanAmounts = new uint256[](2);
        minLoanAmounts[0] = 1;
        minLoanAmounts[1] = 1;
        bytes[] memory loanAssets = new bytes[](1);
        loanAssets[0] = abi.encode(WETH_ASSETT);
        bytes[] memory collAssets = new bytes[](1);
        collAssets[0] = abi.encode(USDC_ASSETT);
        uint256[] memory minCollateralRatio = new uint256[](2);
        minCollateralRatio[0] = 15e17; // 1.5 represented as 15e17 with 18 decimal places precision.
        minCollateralRatio[1] = 17e17; // 1.7 represented as 17e17 with 18 decimal places precision.
        PluginReference[] memory loanOracles = new PluginReference[](1);
        bool isLeverage = false;
        // loanOracles[0] = PluginReference({
        //     addr: address(uniOraclePlugin),
        //     parameters: abi.encode(
        //         UniV3Oracle.Parameters({
        //             pathFromEth: abi.encodePacked(TC.USDC, uint24(500), C.WETH),
        //             pathToEth: abi.encodePacked(C.WETH, uint24(500), TC.USDC),
        //             twapTime: 300
        //         })
        //         )
        // });
        loanOracles[0] = PluginReference({
            addr: address(staticOracle),
            parameters: abi.encode(StaticOracle.Parameters({number: 2000e18}))
        });
        console.log("oracle close price", staticOracle.getClosePrice(loanOracles[0].parameters));
        console.log("oracle open price", staticOracle.getOpenPrice(loanOracles[0].parameters));

        PluginReference[] memory collOracles = new PluginReference[](1);
        collOracles[0] = PluginReference({
            addr: address(staticOracle),
            parameters: abi.encode(StaticOracle.Parameters({number: 1e18}))
        });
        console.log("oracle close price", staticOracle.getOpenPrice(collOracles[0].parameters));
        console.log("oracle open price", IOracle(loanOracles[0].addr).getOpenPrice(collOracles[0].parameters));
        address[] memory factories = new address[](1);
        // factories[0] = address(uniV3HoldFactory);
        factories[0] = address(walletFactory);

        PluginReference memory assessor = PluginReference({
            addr: address(assessorPlugin),
            parameters: abi.encode(
                StandardAssessor.Parameters({
                    originationFeeValue: 0,
                    originationFeePercentage: 0,
                    interestRate: 0,
                    profitShareRate: 0
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
                isLeverage: isLeverage,
                maxDuration: 7 days,
                minCollateralRatio: minCollateralRatio,
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
            initCollateralRatio: 15e17, // 150%
            positionParameters: abi.encode(WalletFactory.Parameters({recipient: borrowerAccountParams.owner}))
        });

        return
            Fill({
                account: PluginReference({addr: address(accountPlugin), parameters: abi.encode(borrowerAccountParams)}),
                loanAmount: LOAN_AMOUNT, // must be valid with init CR and available collateral value
                takerIdx: 0,
                loanAssetIdx: 0,
                collAssetIdx: 0,
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
