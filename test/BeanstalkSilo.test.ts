// SPDX-License-Identifier: MIT
// solhint-disable

import { ethers } from "hardhat";
import { expect } from 'chai';
import { Contract, Signer } from "ethers";

import IAssessor from "../artifacts/src/interfaces/IAssessor.sol/IAssessor.json";
import  IERC20  from "../artifacts/@openzeppelin/contracts/token/ERC20/IERC20.sol/IERC20.json";


import * as Tractor from "../artifacts/@tractor/Tractor.sol/Tractor.json";


import { SoloAccount } from "src/plugins/account/implementations/SoloAccount.sol";
import { IPosition } from "src/interfaces/IPosition.sol";
import { IBookkeeper } from "src/interfaces/IBookkeeper.sol";
import { ILiquidator } from "src/interfaces/ILiquidator.sol";
import { IOracle } from "src/interfaces/IOracle.sol";
import { StandardAssessor } from "src/plugins/assessor/implementations/StandardAssessor.sol";
import { StaticOracle } from "src/plugins/oracle/implementations/StaticOracle.sol";
import { ChainlinkOracle } from "src/plugins/oracle/implementations/ChainlinkOracle.sol";
import { BeanOracle } from "src/plugins/oracle/implementations/BeanOracle.sol";
import { WalletFactory } from "src/plugins/position/implementations/Wallet.sol";
import { BeanstalkSiloFactory } from "src/plugins/position/implementations/BeanstalkSilo.sol";
import { Bookkeeper } from "src/Bookkeeper.sol";
import {
  IndexPair,
  PluginReference,
  BorrowerConfig,
  Order,
  Fill,
  Agreement,
} from "src/libraries/LibBookkeeper.sol";
import { TestUtils } from "test/TestUtils.sol";
import { C } from "src/libraries/C.sol";
import { TC } from "test/TC.sol";
import "src/libraries/LibUtils.sol";



describe("BeanstalkSilo", function () {
  let bookkeeper: IBookkeeper;
  let accountPlugin: IAccount;
  let assessorPlugin: IAssessor;
  let liquidatorPlugin: ILiquidator;
  let chainlinkOracle: IOracle;
  let staticOracle: IOracle;
  let beanOracle: IOracle;
  let walletFactory: IPosition;
  let beanstalkSiloFactory: IPosition;

  const PEPE = "0x6982508145454Ce325dDbE47a25d4ec3d2311933";
  const SHIB = "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE";

  const WETH_ASSET = {
    addr: C.WETH,
    decimals: 18,
  };

  const USDC_ASSET = {
    addr: TC.USDC,
    decimals: TC.USDC_DECIMALS,
  };

  const WETH_ASSETT = {
    addr: C.WETH,
    decimals: 18,
  };

  const USDC_ASSETT = {
    addr: TC.USDC,
    decimals: TC.USDC_DECIMALS,
  };

  const LENDER_PRIVATE_KEY = 111;
  const BORROWER_PRIVATE_KEY = 222;
  const LIQUIDATOR_PRIVATE_KEY = 333;
  const LOAN_AMOUNT = 1e17;

  const ASSETS = [WETH_ASSET, USDC_ASSET];

  before(async function () {
    // Deploy your contracts and set them to the respective variables.
    // Example:
    // const Bookkeeper = await ethers.getContractFactory("Bookkeeper");
    // bookkeeper = await Bookkeeper.deploy();
  });

  beforeEach(async function () {
    // Set up your contracts and state before each test case.
    // Example:
    // const SoloAccount = await ethers.getContractFactory("SoloAccount");
    // accountPlugin = await SoloAccount.deploy(bookkeeper.address);
  });

  it("should test_FillAndDepositSilo", async function () {
    const lender = ethers.Wallet.createRandom().connect(provider);
    const borrower = ethers.Wallet.createRandom().connect(provider);

    const lenderAccountParams = {
      owner: lender.address,
      salt: ethers.utils.formatBytes32String("0"),
    };
    const borrowerAccountParams = {
      owner: borrower.address,
      salt: ethers.utils.formatBytes32String("0"),
    };

    await fundAccount(lenderAccountParams);
    await fundAccount(borrowerAccountParams);

    expect.equal(
      await accountPlugin.getBalance(
        WETH_ASSET,
        ethers.utils.defaultAbiCoder.encode(
          ["tuple(address owner, bytes32 salt)"],
          [lenderAccountParams]
        )
      ),
      12e18
    );
    expect.isBelow(
      (await accountPlugin.getBalance(
        USDC_ASSET,
        ethers.utils.defaultAbiCoder.encode(
          ["tuple(address owner, bytes32 salt)"],
          [borrowerAccountParams]
        )
      )).toNumber(),
      5_000 * 10 ** TC.USDC_DECIMALS
    );

    const order = createOrder(lenderAccountParams);
    const packedData = bookkeeper.packDataField(
      ethers.utils.defaultAbiCoder.encode(["uint8", "bytes"], [1, order])
    );
    const orderBlueprint = {
      publisher: lender.address,
      data: packedData,
      maxNonce: ethers.constants.MaxUint256,
      startTime: 0,
      endTime: ethers.constants.MaxUint256,
    };

    await bookkeeper.createSignedBlueprint(orderBlueprint);

    const fill = createFill(borrowerAccountParams);
    await vm.prank(borrower);
    await bookkeeper.fillOrder(fill);

    expect.isBelow(
      (await accountPlugin.getBalance(
        USDC_ASSET,
        ethers.utils.defaultAbiCoder.encode(
          ["tuple(address owner, bytes32 salt)"],
          [borrowerAccountParams]
        )
      )).toNumber(),
      5_000 * 10 ** TC.USDC_DECIMALS
    );

    // Move time and block forward arbitrarily.
    // vm.warp(block.timestamp + 5 days);
    // vm.roll(block.number + (5 days / 12));

    const { agreementSignedBlueprint, agreement } =
      await retrieveAgreementFromLogs();

    console.log("lender account", await accountPlugin.getBalance(WETH_ASSET, ethers.utils.defaultAbiCoder.encode(["tuple(address owner, bytes32 salt)"], [lenderAccountParams])));
    console.log("borrower wallet", (await IERC20(USDC_ASSETT.addr).balanceOf(borrower.address)).toString());
    console.log("Bean:ETH LP", (await IERC20("0xBEA0e11282e2bB5893bEcE110cF199501e872bAd").balanceOf(agreement.position.addr)).toString());
  });

  async function fundAccount(accountParams: any) {
    // Implement your fundAccount function here.
  }

  function createOrder(accountParams: any) {
    // Implement your createOrder function here.
  }

  function createFill(borrowerAccountParams: any) {
    // Implement your createFill function here.
  }

  async function retrieveAgreementFromLogs() {
    // Implement your retrieveAgreementFromLogs function here.
  }
});
