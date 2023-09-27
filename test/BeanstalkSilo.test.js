// SPDX-License-Identifier: MIT
// solhint-disable


const { expect } = require("chai");
const { ethers } = require('hardhat');
const crypto = require('crypto');




describe("test_BeanstalkSilo", function () {

  const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; 
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
  let bookkeeper;
  let soloAccount;
  let standardAssessor;
  let staticOracle;
  let wallet;

  before(async function () {
    // Deploy LibUtilsPublic library
    const libUtilsPublic = await hre.ethers.deployContract("LibUtilsPublic");
    console.log("LibUtilsPublic address", await libUtilsPublic.getAddress());

    // Deploy Bookkeeper contract
    bookkeeper = await ethers.deployContract("Bookkeeper");
    console.log("Bookkeeper address", await bookkeeper.getAddress());
  
    // Link LibUtilsPublic library and deploy SoloAccount contract
    const libaddress =  await libUtilsPublic.getAddress();
    const soloAccountFactory = await ethers.getContractFactory("SoloAccount",{ 
      libraries: {
        LibUtilsPublic: libaddress
      },
    });
    soloAccount = await soloAccountFactory.deploy(bookkeeper.getAddress());
    console.log("SoloAccount address", await soloAccount.getAddress());

    // Deploy StandardAssessor contract
    standardAssessor = await ethers.deployContract("StandardAssessor");
    console.log("StandardAssessor address", await standardAssessor.getAddress());
  
    // Deploy Static Oracle contract
    staticOracle = await ethers.deployContract("StaticOracle");
    console.log("StaticOracle address", await staticOracle.getAddress());

    // Link LibUtilsPublic library and deploy Wallet contract
    const walletFactory = await ethers.getContractFactory("WalletFactory",{ 
      libraries: {
        LibUtilsPublic: libaddress
      },
    });
    wallet = await walletFactory.deploy(bookkeeper.getAddress());
    console.log("Wallet address", await wallet.getAddress());

    });


    it("should fill order and deposit in Beanstalk Silo", async function () {

      const abiCoder = ethers.AbiCoder.defaultAbiCoder();
      const WETH_Asset_data = abiCoder.encode(
          ["address", "uint8"],
          [WETH_ASSET.addr, WETH_ASSET.decimals]
      );
    
      const USDC_Asset_data = abiCoder.encode(
        ["address", "uint8"],
        ["0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6]
      );
    
      //Create lender and borrower accounts and fund with ETH and USDC

      const [funder] = await ethers.getSigners(); // get the default account to fund others
      const lender = ethers.Wallet.createRandom().connect(ethers.provider);
      const borrower = ethers.Wallet.createRandom().connect(ethers.provider);
      
      // const balancebefore = await ethers.provider.getBalance(borrower.address);
      // console.log(`Balance of address ${borrower.address}: ${balancebefore.toString()} wei`);
    
      // Sending ETH to the lender and borrower from the funder
      await funder.sendTransaction({
        to: lender.address,
        value: BigInt(1e18)
      });
    
      await funder.sendTransaction({
        to: borrower.address,
        value: BigInt(1e18)
      });

    // Send USDC from USDC Whale
    const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
    const WHALE_ADDRESS = "0x78605Df79524164911C144801f41e9811B7DB73D"; 

    // Impersonate the whale account
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [WHALE_ADDRESS],
    });

    const usdcWhale = await ethers.getSigner(WHALE_ADDRESS);

    // Use the whale signer to send USDC
    const usdc = await ethers.getContractAt("IERC20", USDC_ADDRESS);
    await usdc.connect(usdcWhale).transfer(lender.address, BigInt(1000e6));
    await usdc.connect(usdcWhale).transfer(borrower.address, BigInt(1000e6));

    //Log balances
    const lenderBalanceETH = await ethers.provider.getBalance(lender.address);
    console.log("Lender wei",lenderBalanceETH.toString());
    const borrowerBalanceETH = await ethers.provider.getBalance(borrower.address);
    console.log("Borrower Wei",borrowerBalanceETH.toString());
   
    const lenderBalanceUSDC = await usdc.balanceOf(lender.address);
    console.log("Lender USDC",lenderBalanceUSDC.toString());
    const borrowerBalanceUSDC = await usdc.balanceOf(borrower.address);
    console.log("Borrower USDC",borrowerBalanceUSDC.toString());

    const USDCContract = await ethers.getContractAt("IERC20", USDC);
    await USDCContract.connect(lender).approve(soloAccount.getAddress(), BigInt(1000e6));

    const allowance = await USDCContract.allowance(lender.getAddress(), soloAccount.getAddress());
    console.log("Allowance: ", allowance.toString());
    
    const lenderParameters =  abiCoder.encode(
      ["address", "bytes32"], 
      [lender.address, "0x41d792a5e9f694f4663a807ed278c9b1660e84045b78e44f4ea456a1a434ee8b"]
    )

      // Connect the soloAccount contract instance to the lender's signer
      const soloAccountConnectedToLender = soloAccount.connect(lender);

      // Now call loadFromUser with the connected contract instance
      await soloAccountConnectedToLender.loadFromUser(
        USDC_Asset_data, 
        BigInt(500e6), 
        lenderParameters
      );

      const lenderBalance = await soloAccountConnectedToLender.getBalance(USDC_Asset_data,lenderParameters)
      console.log("lender balance",lenderBalance)


    });

    

  });

