// SPDX-License-Identifier: MIT
// solhint-disable



import { expect } from "chai";
import { ethers } from "ethers";
import  IERC20  from "../artifacts/@openzeppelin/contracts/token/ERC20/IERC20.sol/IERC20.json" assert { type: 'json' };
import * as Tractor from "../artifacts/@tractor/Tractor.sol/Tractor.json" assert { type: 'json' };


import * as Libbookkeeper from "../artifacts/src/libraries/LibBookkeeper.sol/LibBookkeeper.json" assert { type: 'json' };
import * as C from "../artifacts/src/libraries/C.sol/C.json" assert { type: 'json' };
import * as LibUtils from "../artifacts/src/libraries/LibUtils.sol/LibUtils.json" assert { type: 'json' };



describe("BeanstalkSilo", function () {

  
  const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; 
  const PEPE = "0x6982508145454Ce325dDbE47a25d4ec3d2311933";
  const SHIB = "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE";
  const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
  
  const WETH_ASSET = {
    addr: WETH,
    decimals: 18,
  };

  const USDC_ASSET = {
    addr: USDC,
    decimals: 6,
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
    const provider = ethers.provider;
    const lender = ethers.Wallet.createRandom().connect(provider);
    const borrower = ethers.Wallet.createRandom().connect(provider);

  });
});
