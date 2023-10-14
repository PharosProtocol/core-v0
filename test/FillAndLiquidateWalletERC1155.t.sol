// // SPDX-License-Identifier: MIT
// // solhint-disable

// pragma solidity 0.8.19;

// /**
//  * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
//  * comprehensive as each unique implementation will likely need its own unique tests.
//  */

// import "@forge-std/Test.sol";
// import "@forge-std/console.sol";

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
// import {Blueprint, SignedBlueprint, Tractor} from "@tractor/Tractor.sol";

// import {SoloAccount} from "src/plugins/account/implementations/SoloAccount.sol";
// //import {SoloAccount} from "src/plugins/account/implementations/SoloAccount.sol";
// import {IAssessor} from "src/interfaces/IAssessor.sol";
// import {IPosition} from "src/interfaces/IPosition.sol";
// import {IBookkeeper} from "src/interfaces/IBookkeeper.sol";
// import {ILiquidator} from "src/interfaces/ILiquidator.sol";
// import {StandardLiquidator} from "src/plugins/liquidator/implementations/StandardLiquidator.sol";
// import {IOracle} from "src/interfaces/IOracle.sol";
// import {StandardAssessor} from "src/plugins/assessor/implementations/StandardAssessor.sol";
// import {StaticOracle} from "src/plugins/oracle/implementations/StaticOracle.sol";
// import {ChainlinkOracle} from "src/plugins/oracle/implementations/ChainlinkOracle.sol";
// import {BeanOracle} from "src/plugins/oracle/implementations/BeanOracle.sol";
// import {BeanDepositOracle} from "src/plugins/oracle/implementations/BeanDepositOracle.sol";
// import {WalletFactory} from "src/plugins/position/implementations/Wallet.sol";
// import {BeanstalkSiloFactory} from "src/plugins/position/implementations/BeanstalkSilo.sol";
// import "lib/EIP-5216/ERC1155ApprovalByAmount.sol";



// import {Bookkeeper} from "src/Bookkeeper.sol";
// import {IndexPair, PluginReference, BorrowerConfig, Order, Fill, Agreement} from "src/libraries/LibBookkeeper.sol";

// import {TestUtils} from "test/TestUtils.sol";

// import {C} from "src/libraries/C.sol";
// import {TC} from "test/TC.sol";
// import "src/libraries/LibUtils.sol";
// import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";


// struct FillerData{
//         uint256 tokenId;
//         address account;
//     }

// struct LiquidationLogic {
//     address payable[] destinations;
//     bytes[] data;
//     bool[] delegateCalls;
// }

// interface ISilo {

//     function increaseDepositAllowance(
//         address spender,
//         address token,
//         uint256 addedValue
//     ) external returns (bool);

//     function depositAllowance(
//         address owner,
//         address spender,
//         address token
//     ) external view returns (uint256);

// }

// contract FillAndClose is TestUtils {
//     IBookkeeper public bookkeeper;
//     IAccount public accountPlugin;
//     IAssessor public assessorPlugin;
//     ILiquidator public liquidatorPlugin;
//     IOracle public chainlinkOracle;
//     IOracle public staticOracle;
//     IOracle public beanOracle;
//     IOracle public beanDepositOracle;
//     IPosition public walletFactory;
//     IPosition public beanstalkSiloFactory;



//     Asset WETH_ASSET = Asset({standard:1, addr: C.WETH, decimals: 18, tokenId: 0, data: ""});
//     Asset USDC_ASSET = Asset({standard:1, addr: TC.USDC, decimals: TC.USDC_DECIMALS, tokenId: 0, data: ""});
//     Asset Bean_Deposit = Asset({standard:3, addr: 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5, decimals: 18, tokenId: 0, data: ""});

    
//     bytes constant WETH_ASSET_Encoded = abi.encode(Asset({standard:1, addr: C.WETH, decimals: 18, tokenId: 0, data: ""}));
//     bytes constant USDC_ASSET_Encoded = abi.encode(Asset({standard:1,addr: TC.USDC, decimals: TC.USDC_DECIMALS, tokenId: 0, data: ""}));
//     bytes constant Bean_Deposit_Encoded = abi.encode(Asset({standard:3, addr: 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5, decimals: 18, tokenId: 0, data: ""}));
//     bytes constant Bean_DepositId_Encoded = abi.encode(Asset({standard:3, addr: 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5, decimals: 18, tokenId: 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b, data: ""}));

//     uint256 LENDER_PRIVATE_KEY = 111;
//     uint256 BORROWER_PRIVATE_KEY = 222;
//     uint256 LIQUIDATOR_PRIVATE_KEY = 333;
//     uint256 LOAN_AMOUNT = 200e18 ;
//     Asset[] ASSETS;

//     constructor() {
//         ASSETS.push(Asset({standard:1, addr: C.WETH, decimals: 18, tokenId: 0, data: ""})); 
//         ASSETS.push(Asset({standard:1, addr: TC.USDC, decimals: TC.USDC_DECIMALS, tokenId: 0, data: ""})); 
//         ASSETS.push(Asset({standard:3, addr: 0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5, decimals: 0, tokenId: 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b, data: ""}));
//     }

//     function setUp() public {
//         vm.recordLogs();
//         vm.createSelectFork(vm.rpcUrl(TC.CHAIN_NAME), TC.BLOCK_NUMBER); // NOTE ensure this is more recent than deployments.

//         // For local deploy of contracts latest local changes.
//         bookkeeper = IBookkeeper(address(new Bookkeeper()));
//         accountPlugin = IAccount(address(new SoloAccount(address(bookkeeper))));
//         assessorPlugin = IAssessor(address(new StandardAssessor()));
//         staticOracle = IOracle(address(new StaticOracle()));
//         beanDepositOracle = IOracle(address(new BeanDepositOracle()));
//         walletFactory = IPosition(address(new WalletFactory(address(bookkeeper))));
//         chainlinkOracle= IOracle(address(new ChainlinkOracle()));
//         beanOracle= IOracle(address(new BeanOracle()));
//         beanstalkSiloFactory= IPosition(address(new BeanstalkSiloFactory((address(bookkeeper)))));
//         liquidatorPlugin = ILiquidator(address(new StandardLiquidator()));

//     }

//     // Using Bean deposit as collateral, borrow USDC
    
//     function test_FillAndClose() public {
//         address lender = vm.addr(LENDER_PRIVATE_KEY);
//         address borrower = vm.addr(BORROWER_PRIVATE_KEY);
//         address liquidatorAddr = vm.addr(LIQUIDATOR_PRIVATE_KEY);

//         SoloAccount.Parameters memory lenderAccountParams = SoloAccount.Parameters({owner: lender, salt: bytes32(0)});
//         SoloAccount.Parameters memory borrowerAccountParams = SoloAccount.Parameters({
//             owner: borrower,
//             salt: bytes32(0)
//         });

//         fundAccount(lenderAccountParams);
//         fundAccount(borrowerAccountParams);
//         fundLiquidator(liquidatorAddr);

//         assertEq(accountPlugin.getBalance(WETH_ASSET_Encoded, abi.encode(lenderAccountParams),""), 12e18);
//         assertEq(
//             accountPlugin.getBalance(USDC_ASSET_Encoded, abi.encode(borrowerAccountParams),""),
//             5_000e18
//         );
//         console.log("borrower account",accountPlugin.getBalance(USDC_ASSET_Encoded, abi.encode(borrowerAccountParams),"") );

//         // Transfer deposit from whale to borrower
//         address whale = 0xF1A621FE077e4E9ac2c0CEfd9B69551dB9c3f657;
//         console.log("LP amount under Bean Deposit in whale's wallet", IOracle(address(beanDepositOracle)).getClosePrice("",abi.encode(FillerData({tokenId: 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b, account: whale})))) ;
//         console.log("whale wallet balance",IERC1155(Bean_Deposit.addr).balanceOf( whale, 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b));


//         console.log("borrower wallet balance",IERC1155(Bean_Deposit.addr).balanceOf( address(borrower), 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b));
//         vm.prank(whale);
//         IERC1155(Bean_Deposit.addr).safeTransferFrom(whale, borrower, 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b, 11327804468626582811, "");
//         console.log("===TRANSFER FROM WHALE====");

//         console.log("borrower wallet balance using IERC1155",IERC1155(Bean_Deposit.addr).balanceOf( address(borrower), 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b));

       
//         vm.prank(borrower);
//         ISilo(Bean_Deposit.addr).increaseDepositAllowance(address(accountPlugin),0xBEA0e11282e2bB5893bEcE110cF199501e872bAd,type(uint256).max);
//         vm.prank(address(borrower));
//         accountPlugin.loadFromUser(Bean_DepositId_Encoded, 11327804468626582811, abi.encode(borrowerAccountParams));
//         console.log("===LOAD ACCOUNT===");
//         console.log("plugin account balance using IERC1155",IERC1155(Bean_Deposit.addr).balanceOf( address(accountPlugin), 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b));
//         console.log("borrower wallet balance",IERC1155(Bean_Deposit.addr).balanceOf( address(borrower), 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b));
//         console.log("borrower account balance using get balance",accountPlugin.getBalance(Bean_DepositId_Encoded, abi.encode(borrowerAccountParams),""));
//         console.log("plugin account address", address(accountPlugin) );
//         console.log("Deposit price in USD", IOracle(address(beanDepositOracle)).getClosePrice("",abi.encode(FillerData({tokenId: 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b, account: address(accountPlugin)})))) ;



//         Order memory order = createOrder(lenderAccountParams);
//         bytes memory packedData;
//         packedData = bookkeeper.packDataField(bytes1(uint8(Bookkeeper.BlueprintDataType.ORDER)), abi.encode(order));
//         // console.log("packedData:");
//         // console.logBytes(packedData);
//         Blueprint memory orderBlueprint = Blueprint({
//             publisher: lender,
//             data: packedData,
//             maxNonce: type(uint256).max,
//             startTime: 0,
//             endTime: type(uint256).max
//         });

//         // console.log("blueprint data at encoding:");
//         // console.logBytes(orderBlueprint.data);
//         SignedBlueprint memory orderSignedBlueprint = createSignedBlueprint(orderBlueprint, LENDER_PRIVATE_KEY);

//         Fill memory fill = createFill(borrowerAccountParams);
//         vm.prank(borrower);
//         bookkeeper.fillOrder(fill, orderSignedBlueprint);
//         console.log("===ORDER FILLED===");
        
//         (SignedBlueprint memory agreementSignedBlueprint, Agreement memory agreement) = retrieveAgreementFromLogs();

//         console.log("collateral in MPC using using IERC1155",IERC1155(Bean_Deposit.addr).balanceOf( address(agreement.position.addr), 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b));
//         console.log("collateral in MPC using getCloseAmount", IPosition(agreement.position.addr).getCloseAmount(agreement));

//         deal(USDC_ASSET.addr, agreement.position.addr, 5_000 * (10 ** TC.USDC_DECIMALS), true);
//         console.log("USDC in MPC",IERC20(USDC_ASSET.addr).balanceOf(agreement.position.addr));
      
//         // Move time and block forward arbitrarily.
//         vm.warp(block.timestamp + 10 days);
//         vm.roll(block.number + (10 days / 12));
        
//         console.log("Liquidator reward", liquidatorPlugin.getReward(agreement));
//         uint256 liquidatorRewardInColl = liquidatorPlugin.getReward(agreement)*C.RATIO_FACTOR/IOracle(agreement.collOracle.addr).getClosePrice(agreement.collOracle.parameters, agreement.fillerData);
//         bytes memory liquidatorLogic= prepareLiquidatorLogic(agreement,abi.encode(lenderAccountParams),abi.encode(borrowerAccountParams),liquidatorRewardInColl);
//         vm.deal(agreement.position.addr, 2e18);
        
//         //console.log("lender account USDC", accountPlugin.getBalance(USDC_ASSET_Encoded, abi.encode(lenderAccountParams),agreement.fillerData));
//         //Liquidate the agreement
//         vm.prank(liquidatorAddr);
//         bookkeeper.triggerLiquidation(agreementSignedBlueprint,liquidatorLogic);
//         console.log("====AGREEMENT LIQUIDATED====");
//         //console.log("lender account USDC", accountPlugin.getBalance(USDC_ASSET_Encoded, abi.encode(lenderAccountParams),agreement.fillerData));
//         console.log("borrower account Bean Deposit", accountPlugin.getBalance(Bean_DepositId_Encoded, abi.encode(borrowerAccountParams),agreement.fillerData));
//         console.log("collateral in MPC using getCloseAmount", IPosition(agreement.position.addr).getCloseAmount(agreement));
//         console.log("collateral in MPC using using IERC1155",IERC1155(Bean_Deposit.addr).balanceOf( address(agreement.position.addr), 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b));
       
//     }


//     function fundAccount(SoloAccount.Parameters memory accountParams) private {
//         vm.deal(accountParams.owner, 2e18);
//         wethDeal(accountParams.owner, 12e18);
//         deal(USDC_ASSET.addr, accountParams.owner, 5_000 * (10 ** TC.USDC_DECIMALS), true);


//         vm.startPrank(accountParams.owner);
//         IERC20(C.WETH).approve(address(accountPlugin), 12e18);
//         accountPlugin.loadFromUser(WETH_ASSET_Encoded, 12e18, abi.encode(accountParams));
//         IERC20(TC.USDC).approve(address(accountPlugin), 5_000 * (10 ** TC.USDC_DECIMALS));
//         accountPlugin.loadFromUser(USDC_ASSET_Encoded, 5_000e18, abi.encode(accountParams));
//         vm.stopPrank();
//     }

//     function fundLiquidator(address liquidator) private {
//         vm.deal(liquidator, 2e18);
//         wethDeal(liquidator, 12e18);
//         deal(USDC_ASSET.addr, liquidator, 5_000 * (10 ** TC.USDC_DECIMALS), true);

//     }

//     function createOrder(SoloAccount.Parameters memory accountParams) private view returns (Order memory) {
//         // Set individual structs here for cleanliness and solidity ease.
//         PluginReference memory account = PluginReference({
//             addr: address(accountPlugin),
//             parameters: abi.encode(accountParams)
//         });

//         address[] memory fillers = new address[](0);
//         uint256[] memory minLoanAmounts = new uint256[](2);
//         minLoanAmounts[0] = 1;
//         minLoanAmounts[1] = 1;
//         bytes[] memory loanAssets = new bytes[](1);
//         loanAssets[0] = abi.encode(USDC_ASSET);
//         bytes[] memory collAssets = new bytes[](1);
//         collAssets[0] = abi.encode(Bean_Deposit);
//         uint256[] memory minCollateralRatio = new uint256[](2);
//         minCollateralRatio[0] = 15e17; // 1.5 represented as 15e17 with 18 decimal places precision.
//         minCollateralRatio[1] = 17e17; // 1.7 represented as 17e17 with 18 decimal places precision.
//         bool isLeverage = false;
//         PluginReference[] memory loanOracles = new PluginReference[](1);
//         loanOracles[0] = PluginReference({
//             addr: address(staticOracle),
//             parameters: abi.encode(StaticOracle.Parameters({number: 1e18}))
//         });

//         PluginReference[] memory collOracles = new PluginReference[](1);
//         collOracles[0] = PluginReference({
//             addr: address(beanDepositOracle),
//             parameters: ""
//         });
//         address[] memory factories = new address[](1);
//         //factories[0] = address(beanstalkSiloFactory);
//         factories[0] = address(walletFactory);


//         PluginReference memory assessor = PluginReference({
//             addr: address(assessorPlugin),
//             parameters: abi.encode(
//                 StandardAssessor.Parameters({
//                     originationFeeValue: 0,
//                     originationFeePercentage: 0,
//                     interestRate: 0,
//                     profitShareRate: 0
//                 })
//             )
//         });

//         PluginReference memory liquidator = PluginReference({addr: address(liquidatorPlugin), parameters: abi.encode(
//                 StandardLiquidator.Parameters({
//                     fixedFee: 0,
//                     percentageFee: 4e18
//                 })
//             )});
//         // Lender creates an offer.
//         return
//             Order({
//                 minLoanAmounts: minLoanAmounts,
//                 loanAssets: loanAssets,
//                 collAssets: collAssets,
//                 fillers: fillers,
//                 isLeverage: isLeverage,
//                 maxDuration: 7 days,
//                 minCollateralRatio: minCollateralRatio,
//                 account: account,
//                 assessor: assessor,
//                 liquidator: liquidator,
//                 /* Allowlisted variables */
//                 loanOracles: loanOracles,
//                 collOracles: collOracles,
//                 // Lender would need to list parameters for all possible holdable tokens from all possible lent tokens. Instead just allow a whole factory.
//                 factories: factories,
//                 isOffer: true,
//                 borrowerConfig: BorrowerConfig(0,"")
//             });
//     }

//     function createFill(SoloAccount.Parameters memory borrowerAccountParams) private view returns (Fill memory) {
//         uint256 tokenId = 0xbea0e11282e2bb5893bece110cf199501e872bad00000000000000000000049b;
        
//         BorrowerConfig memory borrowerConfig = BorrowerConfig({
//             collAmount: 11327804468626582811, // 200%
//             positionParameters: ""
//         });

//         return
//             Fill({
//                 account: PluginReference({addr: address(accountPlugin), parameters: abi.encode(borrowerAccountParams)}),
//                 loanAmount: LOAN_AMOUNT, // must be valid with init CR and available collateral value
//                 takerIdx: 0,
//                 loanAssetIdx: 0,
//                 collAssetIdx: 0,
//                 factoryIdx: 0,
//                 fillerData: abi.encode(FillerData({tokenId: tokenId, account: address(accountPlugin)})),
//                 isOfferFill: true,
//                 borrowerConfig: borrowerConfig
//             });
//     }

//     function createSignedBlueprint(
//         Blueprint memory blueprint,
//         uint256 privateKey
//         ) private view returns (SignedBlueprint memory) {
//         bytes32 blueprintHash = bookkeeper.getBlueprintHash(blueprint);
//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, blueprintHash);
        

//         // console.log("blueprint raw hash: ");
//         // console.logBytes32(keccak256(abi.encode(blueprint)));
//         // console.log("blueprint full hash: ");
//         // console.logBytes32(blueprintHash);
//         // console.log("signature: ");
//         // console.logBytes(abi.encodePacked(r, s, v));

//         return
//             SignedBlueprint({blueprint: blueprint, blueprintHash: blueprintHash, signature: abi.encodePacked(r, s, v)});
//     }

//     /// @dev assumes one agreement in getRecordedLogs. idk if gets oldest or newest.
//     function retrieveAgreementFromLogs()
//         private
//         returns (SignedBlueprint memory agreementSignedBlueprint, Agreement memory agreement)
//     {
//         // At this point the position is live. Things are happening and money is being made, hopefully. The agreement
//         // was defined in the Bookkeeper contract and emitted as an event.
//         Vm.Log[] memory entries = vm.getRecordedLogs();
//         // = abi.decode(entries[entries.length - 1].data, (SignedBlueprint));

//         // Extract signed agreement from logs.
//         for (uint256 i; i < entries.length; i++) {
//             // hardcoded event sig for OrderFilled (from brownie console)
//             if (entries[i].topics[0] == 0x21a6001862375a91bbf0eff278ae1eaee77323f67273ed674a16f9607888696f) {
//                 // console.log("entry data:");
//                 // console.logBytes(entries[i].data);
//                 agreementSignedBlueprint = abi.decode(entries[i].data, (SignedBlueprint)); // signed blueprint is only thing in data
//             }
//         }
//         require(agreementSignedBlueprint.blueprintHash != 0x0, "failed to find agreement in logs");
//         (, bytes memory data) = bookkeeper.unpackDataField(agreementSignedBlueprint.blueprint.data);
//         agreement = abi.decode(data, (Agreement));
//     }

//   function prepareLiquidatorLogic(
//     Agreement memory agreement,
//     bytes memory lenderAccountParams,
//     bytes memory borrowerAccountParams,
//     uint256 liquidatorReward
// ) internal view returns (bytes memory liquidatorLogic) {
//     // Define the destinations, data, and delegateCalls arrays
//     address payable[] memory destinations = new address payable[](4);
//     bytes[] memory data = new bytes[](4);
//     bool[] memory delegateCalls = new bool[](4);

//     // Set the destination to the address of the ERC-20 token for the approval call
//     destinations[0] = payable(USDC_ASSET.addr);  // Convert ERC-20 token address to payable

//     // ABI encode the function call to approve
//     data[0] = abi.encodeWithSignature(
//         "approve(address,uint256)",
//         agreement.lenderAccount.addr,
//         agreement.loanAmount  // Assuming you're approving the spender to transfer the loan amount
//     );

//     // Set the delegateCalls flag (set to false for a regular call, true for a delegate call)
//     delegateCalls[0] = false;

//     // Set the destination to the address of the contract with the loadFromPosition function
//     destinations[1] = payable(agreement.lenderAccount.addr);

//     // Prepare the data for the loadFromPosition function call
//     bytes memory assetData = agreement.loanAsset;
//     uint256 amount = agreement.loanAmount;
//     bytes memory accountParameters = lenderAccountParams;

//     // ABI encode the function call to loadFromPosition
//     data[1] = abi.encodeWithSignature(
//         "loadFromPosition(bytes,uint256,bytes)",
//         assetData,
//         amount,
//         accountParameters
//     );

//     // Set the delegateCalls flag (set to false for a regular call, true for a delegate call)
//     delegateCalls[1] = false;

//     // Set the destination to the address for the approval call
//     destinations[2] = payable(0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5);  

//     // ABI encode the function call to approve
//     data[2] = abi.encodeWithSignature(
//         "approveDeposit(address,address,uint256)",
//         agreement.borrowerAccount.addr,
//         0xBEA0e11282e2bB5893bEcE110cF199501e872bAd,
//         agreement.collAmount 
//     );

//     // Set the delegateCalls flag (set to false for a regular call, true for a delegate call)
//     delegateCalls[2] = false;

//     // Set the destination to the address of the contract with the loadFromPosition function
//     destinations[3] = payable(agreement.borrowerAccount.addr);

//     // Prepare the data for the loadFromPosition function call
//     bytes memory assetData2 = Bean_DepositId_Encoded;
//     uint256 amount2 = agreement.collAmount - liquidatorReward;
//     bytes memory accountParameters2 = borrowerAccountParams;

//     // ABI encode the function call to loadFromPosition
//     data[3] = abi.encodeWithSignature(
//         "loadFromPosition(bytes,uint256,bytes)",
//         assetData2,
//         amount2,
//         accountParameters2
//     );

//     // Set the delegateCalls flag (set to false for a regular call, true for a delegate call)
//     delegateCalls[3] = false;

//     // Create the LiquidationLogic struct
//     LiquidationLogic memory logic = LiquidationLogic({
//         destinations: destinations,
//         data: data,
//         delegateCalls: delegateCalls
//     });

//     liquidatorLogic = abi.encode(logic);

//     return liquidatorLogic;
// }

// }
