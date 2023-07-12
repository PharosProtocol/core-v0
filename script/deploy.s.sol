// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@forge-std/Script.sol";
import "src/libraries/LibBookkeeper.sol";
import "src/Bookkeeper.sol";
import "src/libraries/LibUtils.sol";
import "src/modules/account/implementations/SoloAccount.sol";
import "src/modules/oracle/implementations/StaticValue.sol";
import "src/modules/oracle/implementations/UniswapV3Oracle.sol";
import "src/modules/assessor/implementations/StandardAssessor.sol";
import "src/modules/liquidator/implementations/InstantCloseTakeCollateral.sol";
import "src/modules/position/implementations/UniV3Hold.sol";
import "src/modules/position/implementations/Wallet.sol";

// To install forge/cast:
// https://book.getfoundry.sh/getting-started/installation
// To create keystore, run:
// cast wallet new [PATH_TO_A_DIRECTORY]
// to deploy, run:
// forge script script/deploy.s.sol:DeployScript --keystore $DEFAULT_KEYSTORE_PATH --sender $DEFAULT_KEYSTORE_ADDR --rpc-url $GOERLI_RPC_URL --broadcast -vv
// forge script script/deploy.s.sol:DeployScript --keystore $DEFAULT_KEYSTORE_PATH --sender $DEFAULT_KEYSTORE_ADDR --rpc-url $SEPOLIA_RPC_URL --broadcast -vv
// if etherscan verification desired append:
// --verify --etherscan-api-key $ETHERSCAN_TOKEN
// Contract address can be seen in output json file.

// NOTE do not forget to switch constant contract addresses to match deployment chain.

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        // string memory seedPhrase = vm.readFile(".secret");
        // uint256 privateKey = vm.deriveKey(seedPhrase, 0);
        vm.startBroadcast();
        // Utils utils = new Utils();
        // LibBookkeeper libBookkeeper = new LibBookkeeper();
        Bookkeeper bookkeeper = new Bookkeeper();
        new SoloAccount(address(bookkeeper));
        new InstantCloseTakeCollateral(address(bookkeeper));
        // new UniV3HoldFactory(address(bookkeeper));
        new WalletFactory(address(bookkeeper));
        new StandardAssessor();
        new StaticPriceOracle();
        // new UniswapV3Oracle();

        vm.stopBroadcast();
    }
}
