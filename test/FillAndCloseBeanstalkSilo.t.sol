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
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Blueprint, SignedBlueprint, Tractor} from "@tractor/Tractor.sol";

import {SoloAccount} from "src/plugins/account/implementations/SoloAccount.sol";
//import {SoloAccount} from "src/plugins/account/implementations/SoloAccount.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {IBookkeeper} from "src/interfaces/IBookkeeper.sol";
import {ILiquidator} from "src/interfaces/ILiquidator.sol";
import {StandardLiquidator} from "src/plugins/liquidator/implementations/StandardLiquidator.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {StandardAssessor} from "src/plugins/assessor/implementations/StandardAssessor.sol";
import {StaticOracle} from "src/plugins/oracle/implementations/StaticOracle.sol";
import {ChainlinkOracle} from "src/plugins/oracle/implementations/ChainlinkOracle.sol";
import {BeanOracle} from "src/plugins/oracle/implementations/BeanOracle.sol";
import {BeanDepositOracle} from "src/plugins/oracle/implementations/BeanDepositOracle.sol";
import {WalletFactory} from "src/plugins/position/implementations/Wallet.sol";
import {BeanstalkSiloFactory} from "src/plugins/position/implementations/BeanstalkSilo.sol";
import "lib/EIP-5216/ERC1155ApprovalByAmount.sol";



import {Bookkeeper} from "src/Bookkeeper.sol";
import {IndexPair, PluginReference, BorrowerConfig, Order, Fill, Agreement} from "src/libraries/LibBookkeeper.sol";

import {TestUtils} from "test/TestUtils.sol";

import {C} from "src/libraries/C.sol";
import {TC} from "test/TC.sol";
import "src/libraries/LibUtils.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";


struct FillerData{
        uint256 tokenId;
        address account;
    }




contract FillAndClose is TestUtils {
    IBookkeeper public bookkeeper;
    IAccount public accountPlugin;
    IAssessor public assessorPlugin;
    ILiquidator public liquidatorPlugin;
    IOracle public chainlinkOracle;
    IOracle public staticOracle;
    IOracle public beanOracle;
    IOracle public beanDepositOracle;
    IPosition public walletFactory;
    IPosition public beanstalkSiloFactory;



    Asset WETH_ASSET = Asset({standard:1, addr: C.WETH, decimals: 18, tokenId: 0, data: ""});
    Asset USDC_ASSET = Asset({standard:1, addr: TC.USDC, decimals: TC.USDC_DECIMALS, tokenId: 0, data: ""});
    Asset Bean_Deposit = Asset({standard:3, addr: 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5, decimals: 18, tokenId: 0, data: ""});

    
    bytes constant WETH_ASSET_Encoded = abi.encode(Asset({standard:1, addr: C.WETH, decimals: 18, tokenId: 0, data: ""}));
    bytes constant USDC_ASSET_Encoded = abi.encode(Asset({standard:1,addr: TC.USDC, decimals: TC.USDC_DECIMALS, tokenId: 0, data: ""}));
    bytes constant Bean_Deposit_Encoded = abi.encode(Asset({standard:3, addr: 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5, decimals: 18, tokenId: 0, data: ""}));
    bytes constant Bean_DepositId_Encoded = abi.encode(Asset({standard:3, addr: 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5, decimals: 18, tokenId: 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b, data: ""}));

    uint256 LENDER_PRIVATE_KEY = 111;
    uint256 BORROWER_PRIVATE_KEY = 222;
    uint256 LIQUIDATOR_PRIVATE_KEY = 333;
    uint256 LOAN_AMOUNT = 1e18 ;
    Asset[] ASSETS;

    constructor() {
        ASSETS.push(Asset({standard:1, addr: C.WETH, decimals: 18, tokenId: 0, data: ""})); 
        ASSETS.push(Asset({standard:1, addr: TC.USDC, decimals: TC.USDC_DECIMALS, tokenId: 0, data: ""})); 
        ASSETS.push(Asset({standard:3, addr: 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5, decimals: 0, tokenId: 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b, data: ""}));
    }

    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl(TC.CHAIN_NAME), TC.BLOCK_NUMBER); // NOTE ensure this is more recent than deployments.

        // For local deploy of contracts latest local changes.
        bookkeeper = IBookkeeper(address(new Bookkeeper()));
        accountPlugin = IAccount(address(new SoloAccount(address(bookkeeper))));
        assessorPlugin = IAssessor(address(new StandardAssessor()));
        staticOracle = IOracle(address(new StaticOracle()));
        beanDepositOracle = IOracle(address(new BeanDepositOracle()));
        walletFactory = IPosition(address(new WalletFactory(address(bookkeeper))));
        chainlinkOracle= IOracle(address(new ChainlinkOracle()));
        beanOracle= IOracle(address(new BeanOracle()));
        beanstalkSiloFactory= IPosition(address(new BeanstalkSiloFactory((address(bookkeeper)))));
        liquidatorPlugin = ILiquidator(address(new StandardLiquidator()));

    }



    // Using Bean deposit as collateral, borrow USDC

    
    function test_FillAndClose() public {
        address lender = vm.addr(LENDER_PRIVATE_KEY);
        address borrower = vm.addr(BORROWER_PRIVATE_KEY);

        SoloAccount.Parameters memory lenderAccountParams = SoloAccount.Parameters({owner: lender, salt: bytes32(0)});
        SoloAccount.Parameters memory borrowerAccountParams = SoloAccount.Parameters({
            owner: borrower,
            salt: bytes32(0)
        });

        fundAccount(lenderAccountParams);
        fundAccount(borrowerAccountParams);

        console.log("borrower account",accountPlugin.getBalance(USDC_ASSET_Encoded, abi.encode(borrowerAccountParams),"") );

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
        console.log("===ORDER FILLED===");
       
        // // // Move time and block forward arbitrarily.
        // // vm.warp(block.timestamp + 5 days);
        // // vm.roll(block.number + (5 days / 12));
        
        (SignedBlueprint memory agreementSignedBlueprint, Agreement memory agreement) = retrieveAgreementFromLogs();

        console.log("Value of collateral in MPC using getCloseAmount", IPosition(agreement.position.addr).getCloseAmount(agreement));
        console.log("collateral in MPC using IERC20",IERC20(WETH_ASSET.addr).balanceOf(agreement.position.addr));

        deal(USDC_ASSET.addr, agreement.position.addr, 5_000 * (10 ** TC.USDC_DECIMALS), true);
        console.log("USDC in MPC",IERC20(USDC_ASSET.addr).balanceOf(agreement.position.addr));
        console.log("borrower wallet balance",IERC20(WETH_ASSET.addr).balanceOf(address(borrower)));

        vm.prank(borrower);
        bookkeeper.unwindPosition(agreementSignedBlueprint);
        console.log("====UNWIND POSITION====");
        console.log("WETH in MPC",IERC20(WETH_ASSET.addr).balanceOf(agreement.position.addr));
        console.log("Value of collateral in MPC using getCloseAmount", IPosition(agreement.position.addr).getCloseAmount(agreement));

        vm.prank(borrower);
        bookkeeper.closePosition(agreementSignedBlueprint);
        console.log("====AGREEMENT CLOSED====");
        console.log("WETH in MPC",IERC20(WETH_ASSET.addr).balanceOf(agreement.position.addr));
        console.log("Value of collateral in MPC using getCloseAmount", IPosition(agreement.position.addr).getCloseAmount(agreement));
        console.log("borrower WETH wallet balance",IERC20(WETH_ASSET.addr).balanceOf(address(borrower)));
        console.log("lender WETH wallet balance",IERC20(WETH_ASSET.addr).balanceOf(address(lender)));

        // vm.prank(borrower);
        // accountPlugin.unloadToUser(WETH_ASSET_Encoded, 1e17, abi.encode(borrowerAccountParams));
        // vm.prank(lender);
        // accountPlugin.unloadToUser(USDC_ASSET_Encoded, 500e18, abi.encode(lenderAccountParams));
        // console.log("====UNLOAD====");
        // console.log("lender USDC wallet balance",IERC20(USDC_ASSET.addr).balanceOf(address(lender)));

        // console.log("borrower WETH wallet balance",IERC20(WETH_ASSET.addr).balanceOf(address(borrower)));

    }


    function fundAccount(SoloAccount.Parameters memory accountParams) private {
        vm.deal(accountParams.owner, 2e18);
        wethDeal(accountParams.owner, 12e18);
        deal(USDC_ASSET.addr, accountParams.owner, 5_000 * (10 ** TC.USDC_DECIMALS), true);


        vm.startPrank(accountParams.owner);
        IERC20(C.WETH).approve(address(accountPlugin), 12e18);
        accountPlugin.loadFromUser(WETH_ASSET_Encoded, 12e18, abi.encode(accountParams));
        IERC20(TC.USDC).approve(address(accountPlugin), 5_000 * (10 ** TC.USDC_DECIMALS));
        accountPlugin.loadFromUser(USDC_ASSET_Encoded, 5_000e18, abi.encode(accountParams));
        vm.stopPrank();
    }

    function fundLiquidator(address liquidator) private {
        vm.deal(liquidator, 2e18);
        wethDeal(liquidator, 12e18);
        deal(USDC_ASSET.addr, liquidator, 5_000 * (10 ** TC.USDC_DECIMALS), true);

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
        loanAssets[0] = abi.encode(WETH_ASSET);
        bytes[] memory collAssets = new bytes[](1);
        collAssets[0] = abi.encode(WETH_ASSET);
        uint256[] memory minCollateralRatio = new uint256[](2);
        minCollateralRatio[0] = 15e17; // 1.5 represented as 15e17 with 18 decimal places precision.
        minCollateralRatio[1] = 17e17; // 1.7 represented as 17e17 with 18 decimal places precision.
        bool isLeverage = true;
        PluginReference[] memory loanOracles = new PluginReference[](1);
        loanOracles[0] = PluginReference({
            addr: address(chainlinkOracle),
            parameters: abi.encode(ChainlinkOracle.Parameters({addr: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419}))
        });

        PluginReference[] memory collOracles = new PluginReference[](1);
        collOracles[0] = PluginReference({
            addr: address(chainlinkOracle),
            parameters: abi.encode(ChainlinkOracle.Parameters({addr: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419}))
        });
        address[] memory factories = new address[](1);
        //factories[0] = address(beanstalkSiloFactory);
        factories[0] = address(beanstalkSiloFactory);


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

        PluginReference memory liquidator = PluginReference({addr: address(liquidatorPlugin), parameters: abi.encode(
                StandardLiquidator.Parameters({
                    fixedFee: 0,
                    percentageFee: 4e18
                })
            )});
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
                borrowerConfig: BorrowerConfig(0,"")
            });
    }

    function createFill(SoloAccount.Parameters memory borrowerAccountParams) private view returns (Fill memory) {
        uint256 tokenId = 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b;
        
        BorrowerConfig memory borrowerConfig = BorrowerConfig({
            collAmount: 1e18, // 200%
            positionParameters: ""
        });

        return
            Fill({
                account: PluginReference({addr: address(accountPlugin), parameters: abi.encode(borrowerAccountParams)}),
                loanAmount: LOAN_AMOUNT, // must be valid with init CR and available collateral value
                takerIdx: 0,
                loanAssetIdx: 0,
                collAssetIdx: 0,
                factoryIdx: 0,
                fillerData: abi.encode(FillerData({tokenId: tokenId, account: address(accountPlugin)})),
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
