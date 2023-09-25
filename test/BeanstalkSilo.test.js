"use strict";
// SPDX-License-Identifier: MIT
// solhint-disable
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
require("ethers");
const chai_1 = require("chai");
const IERC20_sol_1 = require("@openzeppelin/contracts/token/ERC20/IERC20.sol");
const C_sol_1 = require("src/libraries/C.sol");
const TC_sol_1 = require("test/TC.sol");
require("src/libraries/LibUtils.sol");
describe("BeanstalkSilo", function () {
    let bookkeeper;
    let accountPlugin;
    let assessorPlugin;
    let liquidatorPlugin;
    let chainlinkOracle;
    let staticOracle;
    let beanOracle;
    let walletFactory;
    let beanstalkSiloFactory;
    const PEPE = "0x6982508145454Ce325dDbE47a25d4ec3d2311933";
    const SHIB = "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE";
    const WETH_ASSET = {
        addr: C_sol_1.C.WETH,
        decimals: 18,
    };
    const USDC_ASSET = {
        addr: TC_sol_1.TC.USDC,
        decimals: TC_sol_1.TC.USDC_DECIMALS,
    };
    const WETH_ASSETT = {
        addr: C_sol_1.C.WETH,
        decimals: 18,
    };
    const USDC_ASSETT = {
        addr: TC_sol_1.TC.USDC,
        decimals: TC_sol_1.TC.USDC_DECIMALS,
    };
    const LENDER_PRIVATE_KEY = 111;
    const BORROWER_PRIVATE_KEY = 222;
    const LIQUIDATOR_PRIVATE_KEY = 333;
    const LOAN_AMOUNT = 1e17;
    const ASSETS = [WETH_ASSET, USDC_ASSET];
    before(function () {
        return __awaiter(this, void 0, void 0, function* () {
            // Deploy your contracts and set them to the respective variables.
            // Example:
            // const Bookkeeper = await ethers.getContractFactory("Bookkeeper");
            // bookkeeper = await Bookkeeper.deploy();
        });
    });
    beforeEach(function () {
        return __awaiter(this, void 0, void 0, function* () {
            // Set up your contracts and state before each test case.
            // Example:
            // const SoloAccount = await ethers.getContractFactory("SoloAccount");
            // accountPlugin = await SoloAccount.deploy(bookkeeper.address);
        });
    });
    it("should test_FillAndDepositSilo", function () {
        return __awaiter(this, void 0, void 0, function* () {
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
            yield fundAccount(lenderAccountParams);
            yield fundAccount(borrowerAccountParams);
            chai_1.expect.equal(yield accountPlugin.getBalance(WETH_ASSET, ethers.utils.defaultAbiCoder.encode(["tuple(address owner, bytes32 salt)"], [lenderAccountParams])), 12e18);
            chai_1.expect.isBelow((yield accountPlugin.getBalance(USDC_ASSET, ethers.utils.defaultAbiCoder.encode(["tuple(address owner, bytes32 salt)"], [borrowerAccountParams]))).toNumber(), 5000 * 10 ** TC_sol_1.TC.USDC_DECIMALS);
            const order = createOrder(lenderAccountParams);
            const packedData = bookkeeper.packDataField(ethers.utils.defaultAbiCoder.encode(["uint8", "bytes"], [1, order]));
            const orderBlueprint = {
                publisher: lender.address,
                data: packedData,
                maxNonce: ethers.constants.MaxUint256,
                startTime: 0,
                endTime: ethers.constants.MaxUint256,
            };
            yield bookkeeper.createSignedBlueprint(orderBlueprint);
            const fill = createFill(borrowerAccountParams);
            yield vm.prank(borrower);
            yield bookkeeper.fillOrder(fill);
            chai_1.expect.isBelow((yield accountPlugin.getBalance(USDC_ASSET, ethers.utils.defaultAbiCoder.encode(["tuple(address owner, bytes32 salt)"], [borrowerAccountParams]))).toNumber(), 5000 * 10 ** TC_sol_1.TC.USDC_DECIMALS);
            // Move time and block forward arbitrarily.
            // vm.warp(block.timestamp + 5 days);
            // vm.roll(block.number + (5 days / 12));
            const { agreementSignedBlueprint, agreement } = yield retrieveAgreementFromLogs();
            console.log("lender account", yield accountPlugin.getBalance(WETH_ASSET, ethers.utils.defaultAbiCoder.encode(["tuple(address owner, bytes32 salt)"], [lenderAccountParams])));
            console.log("borrower wallet", (yield (0, IERC20_sol_1.IERC20)(USDC_ASSETT.addr).balanceOf(borrower.address)).toString());
            console.log("Bean:ETH LP", (yield (0, IERC20_sol_1.IERC20)("0xBEA0e11282e2bB5893bEcE110cF199501e872bAd").balanceOf(agreement.position.addr)).toString());
        });
    });
    function fundAccount(accountParams) {
        return __awaiter(this, void 0, void 0, function* () {
            // Implement your fundAccount function here.
        });
    }
    function createOrder(accountParams) {
        // Implement your createOrder function here.
    }
    function createFill(borrowerAccountParams) {
        // Implement your createFill function here.
    }
    function retrieveAgreementFromLogs() {
        return __awaiter(this, void 0, void 0, function* () {
            // Implement your retrieveAgreementFromLogs function here.
        });
    }
});
