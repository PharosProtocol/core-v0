// // SPDX-License-Identifier: MIT
// // solhint-disable

// pragma solidity 0.8.19;


// import "@forge-std/Test.sol";
// import "@forge-std/console.sol";

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {Blueprint, SignedBlueprint, Tractor} from "@tractor/Tractor.sol";

// import {SoloAccount} from "src/plugins/account/implementations/SoloAccount.sol";
// import {IAssessor} from "src/interfaces/IAssessor.sol";
// import {IPosition} from "src/interfaces/IPosition.sol";
// import {IBookkeeper} from "src/interfaces/IBookkeeper.sol";
// import {ILiquidator} from "src/interfaces/ILiquidator.sol";
// import {IOracle} from "src/interfaces/IOracle.sol";
// import {StandardAssessor} from "src/plugins/assessor/implementations/StandardAssessor.sol";
// import {StaticOracle} from "src/plugins/oracle/implementations/StaticOracle.sol";
// import {ChainlinkOracle} from "src/plugins/oracle/implementations/ChainlinkOracle.sol";
// import {BeanOracle} from "src/plugins/oracle/implementations/BeanOracle.sol";
// import {WalletFactory} from "src/plugins/position/implementations/Wallet.sol";

// import {Bookkeeper} from "src/Bookkeeper.sol";
// import {IndexPair, PluginReference, BorrowerConfig, Order, Fill, Agreement} from "src/libraries/LibBookkeeper.sol";

// import {TestUtils} from "test/TestUtils.sol";

// import {C} from "src/libraries/C.sol";
// import {TC} from "test/TC.sol";
// import "src/libraries/LibUtils.sol";

// contract TestOracle is TestUtils {
//     IBookkeeper public bookkeeper;
//     IAccount public accountPlugin;
//     IAssessor public assessorPlugin;
//     ILiquidator public liquidatorPlugin;
//     IOracle public chainlinkOracle;
//     IOracle public staticOracle;
//     IOracle public beanOracle;
//     IPosition public walletFactory;
    
    
//     function setUp() public {
//         vm.recordLogs();
//         vm.createSelectFork(vm.rpcUrl(TC.CHAIN_NAME), TC.BLOCK_NUMBER); 

//         // For local deploy of contracts latest local changes.
//         bookkeeper = IBookkeeper(address(new Bookkeeper()));
//         accountPlugin = IAccount(address(new SoloAccount(address(bookkeeper))));
//         assessorPlugin = IAssessor(address(new StandardAssessor()));
//         staticOracle = IOracle(address(new StaticOracle()));
//         walletFactory = IPosition(address(new WalletFactory(address(bookkeeper))));
//         chainlinkOracle= IOracle(address(new ChainlinkOracle()));
//         beanOracle= IOracle(address(new BeanOracle()));

//         // // For use with pre deployed contracts.
//         // bookkeeper = IBookkeeper(0x96DEA1646129fF9637CE5cCE81E65559af172b92);
//         // accountPlugin = IAccount(0x225D9FaD9081F0E67dD5E4b93E26e85E8F70a9aE);
//         // assessorPlugin = IAssessor(0x5F5baC1aEF241eB4CB0B484bF68d104B00E1F98E);
//         // liquidatorPlugin = ILiquidator(0x1bdD37aFC33C59D0B1572b23B9188531d6aA7cda);
//         // staticOracle = IOracle(0xeE3B0F63eB134a06833b72082362c0a1Ed80B717); // static price
//         // walletFactory = IPosition(0x51b245b41037B966e8709B622Ee735a653e3d40d);
//         // uniOraclePlugin = IOracle(); // static prices
//         // uniV3HoldFactory = IPosition();
//     }



//     // Start Test.
//     function test_Oracles() public {
       

//         bytes memory addressETH = abi.encode(address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419));
//         bytes memory addressBTC = abi.encode(address(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c));
//         bytes memory BYTES_ZERO = new bytes(0);
        
//         console.log("chainlink ETH",chainlinkOracle.getClosePrice(addressETH) );
//         console.log("chainlink BTC",chainlinkOracle.getClosePrice(addressBTC) );
//         console.log( "Bean Price",beanOracle.getClosePrice(BYTES_ZERO) );


//     }
// }