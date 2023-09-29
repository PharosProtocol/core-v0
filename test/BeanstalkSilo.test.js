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
  const LOAN_AMOUNT = BigInt(1e17);

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
    const libaddress = await libUtilsPublic.getAddress();
    const soloAccountFactory = await ethers.getContractFactory("SoloAccount", {
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

    // Link LibUtilsPublic library and deploy WalletFactory contract
    const walletFactory = await ethers.getContractFactory("WalletFactory", {
      libraries: {
        LibUtilsPublic: libaddress
      },
    });
    wallet = await walletFactory.deploy(bookkeeper.getAddress());
    console.log("WalletFactory address", await wallet.getAddress());

    // Deploy BeanstalkSiloFactory contract
    const beanstalkSiloFactory = await ethers.getContractFactory("BeanstalkSiloFactory");
    beanstalkSilo = await beanstalkSiloFactory.deploy(bookkeeper.getAddress());
    console.log("BeanstalkSiloFactory address", await beanstalkSilo.getAddress());

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
    console.log("Lender wei", lenderBalanceETH.toString());
    const borrowerBalanceETH = await ethers.provider.getBalance(borrower.address);
    console.log("Borrower Wei", borrowerBalanceETH.toString());

    const lenderBalanceUSDC = await usdc.balanceOf(lender.address);
    console.log("Lender USDC", lenderBalanceUSDC.toString());
    const borrowerBalanceUSDC = await usdc.balanceOf(borrower.address);
    console.log("Borrower USDC", borrowerBalanceUSDC.toString());

    const USDCContract = await ethers.getContractAt("IERC20", USDC);
    await USDCContract.connect(lender).approve(soloAccount.getAddress(), BigInt(1000e6));

    const allowance = await USDCContract.allowance(lender.getAddress(), soloAccount.getAddress());
    console.log("Allowance: ", allowance.toString());

    const lenderSalt = crypto.randomBytes(32);
    const borrowerSalt = crypto.randomBytes(32);

    const lenderParameters = abiCoder.encode(
      ["address", "bytes32"],
      [lender.address, lenderSalt]
    )
    const borrowerParameters = abiCoder.encode(
      ["address", "bytes32"],
      [borrower.address, borrowerSalt]
    )

    // Connect the soloAccount contract instance to the lender's signer
    const soloAccountConnectedToLender = soloAccount.connect(lender);

    // Now call loadFromUser with the connected contract instance
    await soloAccountConnectedToLender.loadFromUser(
      USDC_Asset_data,
      BigInt(500e6),
      lenderParameters
    );

    const lenderBalance = await soloAccountConnectedToLender.getBalance(USDC_Asset_data, lenderParameters)
    console.log("lender balance", lenderBalance)

    //create order

    const account = {
      addr: lender.address,
      parameters: lenderParameters
    };
    const fillers = [];
    const minLoanAmounts = [1];
    const loanAssets = [WETH_Asset_data];
    const collAssets = [USDC_Asset_data];
    const minCollateralRatio = [BigInt(15e17)];

    const loanOracles = [{
      addr: await staticOracle.getAddress(),
      parameters: abiCoder.encode(
        ["uint256"],
        [BigInt(2000e18)]
      )
    }];

    const collOracles = [{
      addr: await staticOracle.getAddress(),
      parameters: abiCoder.encode(
        ["uint256"],
        [BigInt(1e18)]
      )
    }];

    // Log the open price from the oracle (assuming an IOracle interface)
    const loanOracleOpenPrice = await staticOracle.getOpenPrice(loanOracles[0].parameters);
    console.log("oracle open price", loanOracleOpenPrice.toString());

    const factories = [await beanstalkSilo.getAddress()];

    const assessor = {
      addr: await standardAssessor.getAddress(),
      parameters: abiCoder.encode(
        ["tuple(uint256,uint256,uint256,uint256)"],
        [[0, 0, 0, 0]]
      )
    };


    const liquidator = { addr: await standardAssessor.getAddress(), parameters: "0x00" };

    // Create the order object
    const order = {
      minLoanAmounts,
      loanAssets,
      collAssets,
      fillers,
      isLeverage: false,
      maxDuration: 86400, // 1 day
      minCollateralRatio,
      account,
      assessor,
      liquidator,
      /* Allowlisted variables */
      loanOracles,
      collOracles,
      factories,
      isOffer: true,
      borrowerConfig: { initCollateralRatio: 0, positionParameters: "0x00" }
    };
    console.log(order);

    // Create Fill
    // Construct BorrowerConfig
    const borrowerConfig = {
      initCollateralRatio: BigInt(15e17), // 150%
      positionParameters: "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    };

    // Construct Fill

    const borrowerSaltHex = lenderSalt.toString('hex');

    const fill = {
      account: [borrower.address, `0x${borrowerSaltHex}`],
      loanAmount: LOAN_AMOUNT, // Replace with your constant or a passed parameter
      takerIdx: 0,
      loanAssetIdx: 0,
      collAssetIdx: 0,
      factoryIdx: 0,
      isOfferFill: true,
      borrowerConfig: borrowerConfig
    };

    //console.log("fill",fill);
  
  // Step 1: Pack the order data using the Bookkeeper 
  const orderStructType = [
    'uint256[] minLoanAmounts',
    'bytes[] loanAssets',
    'bytes[] collAssets',
    'uint256[] minCollateralRatio',
    'address[] fillers',
    'bool isLeverage',
    'uint256 maxDuration',
    'tuple(address addr, bytes parameters) account',
    'tuple(address addr, bytes parameters) assessor',
    'tuple(address addr, bytes parameters) liquidator',
    'tuple(address addr, bytes parameters)[] loanOracles',
    'tuple(address addr, bytes parameters)[] collOracles',
    'address[] factories',
    'bool isOffer',
    'tuple(uint256 initCollateralRatio, bytes positionParameters) borrowerConfig'
];
// // To print Order
// function replacer(key, value) {
//   if (typeof value === 'bigint') {
//     return value.toString() + 'n';  // convert BigInt to string and append 'n'
//   } else {
//     return value;
//   }
// }

// // Use the replacer function with JSON.stringify
// console.log(JSON.stringify(order, replacer, 2));
 
const orderData = abiCoder.encode([`tuple(${orderStructType.join(',')})`], [order]);



  const packedData = await bookkeeper.packDataField(
    "0x01",  // Assuming 1 represents Bookkeeper.BlueprintDataType.ORDER
    orderData
  );

  // Step 2: Create a blueprint and sign it
 const maxUint256 = BigInt(2)**BigInt(256) - BigInt(1);

  const orderBlueprint = {
    publisher: lender.address,
    data: packedData,
    maxNonce: maxUint256,
    startTime: 0,
    endTime: maxUint256
  };

  const domain = {
    name: 'pharos',
    version: '0.2.0',
    chainId: 1,  // replace with the actual chainId
    verifyingContract: await bookkeeper.getAddress()
};
const types = {
    OrderBlueprint: [
        { name: 'publisher', type: 'address' },
        { name: 'data', type: 'bytes' },
        { name: 'maxNonce', type: 'uint256' },
        { name: 'startTime', type: 'uint256' },
        { name: 'endTime', type: 'uint256' },
    ]
};

const signature = await lender.signTypedData(domain, types, orderBlueprint);

// Step 3: Create a blueprint hash using the bookkeeper 

  const blueprintHash = await bookkeeper.getBlueprintHash(orderBlueprint);
  
// Create a signed blueprint
const signedBlueprint = {
    blueprint: orderBlueprint,
    blueprintHash: blueprintHash,
    signature: signature
    
};

  //console.log(signedBlueprint);

//Fill loan
const bookkeeperContract = bookkeeper.connect(borrower); 
const txResponse = await bookkeeperContract.fillOrder(fill, signedBlueprint);
});

    

      
    

  });

