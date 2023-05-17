// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/**
 * This is the standard set of tests used to verify an arbitrary Account implementation. It is not expected to be
 * comprehensive as each unique implementation will likely need its own unique tests.
 */

import "forge-std/Test.sol";
import {console} from "lib/forge-std/src/console.sol";
import {HandlerUtils} from "test/TestUtils.sol";
import {Module} from "src/modules/Module.sol";

import "lib/v3-periphery/contracts/libraries/PoolAddress.sol";
import "lib/v3-core/contracts/UniswapV3Pool.sol";
import {FullMath} from "lib/v3-core/contracts/libraries/FullMath.sol";

// import {TestUtils} from "test/LibTestUtils.sol";

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "src/LibUtil.sol";
import {C} from "src/C.sol";
import {UniswapV3Oracle} from "src/modules/oracle/implementations/UniswapV3Oracle.sol";

contract UniswapV3OracleTest is Test, Module {
    UniswapV3Oracle public oracleModule;
    uint256 POOL_USDC_AT_BLOCK = 147_000_000e6;
    uint256 POOL_WETH_AT_BLOCK = 84_000e18;
    Asset WETH_ASSET = Asset({standard: ERC20_STANDARD, addr: address(C.WETH), id: 0, data: ""});

    constructor() {
        COMPATIBLE_LOAN_ASSETS.push(Asset({standard: ERC20_STANDARD, addr: address(0), id: 0, data: ""}));
        COMPATIBLE_COLL_ASSETS.push(Asset({standard: ERC20_STANDARD, addr: address(0), id: 0, data: ""}));
    }

    function POOL_INIT_CODE_HASH() external pure returns (bytes32) {
        return PoolAddress.POOL_INIT_CODE_HASH;
    }

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        // requires fork at known time so valuations are known
        vm.createSelectFork(vm.rpcUrl("mainnet"), 17092863); // seems that test begin at end of block.

        oracleModule = new UniswapV3Oracle();
    }

    function testUnit() public {
        // Uniswap v3 USDC:WETH pool - https://info.uniswap.org/#/pools/0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640
        UniswapV3Oracle.Parameters memory params = UniswapV3Oracle.Parameters({
            pathFromUsd: abi.encodePacked(C.USDC, uint24(500), C.WETH), // addr, uint24, addr, uint24, addr ...
            pathToUsd: abi.encodePacked(C.WETH, uint24(500), C.USDC),
            stepSlippageRatio: C.RATIO_FACTOR / 1000, // 0.1%
            twapTime: 300
        });
        bytes memory parameters = abi.encode(params);

        // Will fail if POOL_INIT_CODE_HASH does not match chain deployed pool creation code hash.
        oracleModule.verifyParameters(WETH_ASSET, parameters);

        // Nearest txn, but exact values are taken from running this code itself.
        // https://etherscan.io/tx/0xdbb4daef28e55f2d5f56de0aab299e5e488f13ba36313d38ab40914f99b63811
        uint256 value = oracleModule.getValue(WETH_ASSET, 119023864514200107128, parameters);
        uint256 amount = oracleModule.getAmount(WETH_ASSET, value, parameters);
        console.log("value: %s", value);
        console.log("amount: %s", amount);
        assertEq(value, 229704367903);
        assertEq(amount, 119023864513731271313);
    }

    // NOTE could add fuzzed path with some creativity.
    /// @notice fuzz testing of getCost. Does not check for correctness.
    function testFuzz_GetCost(uint256 baseAmount) public {
        baseAmount = bound(baseAmount, 0, POOL_WETH_AT_BLOCK);
        // Uniswap v3 USDC:WETH pool - https://info.uniswap.org/#/pools/0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640
        UniswapV3Oracle.Parameters memory params = UniswapV3Oracle.Parameters({
            pathFromUsd: abi.encodePacked(C.USDC, uint24(500), C.WETH), // addr, uint24, addr, uint24, addr ...
            pathToUsd: abi.encodePacked(C.WETH, uint24(500), C.USDC),
            stepSlippageRatio: C.RATIO_FACTOR / 1000, // 0.1%
            twapTime: 300
        });
        bytes memory parameters = abi.encode(params);

        uint256 value = oracleModule.getValue(WETH_ASSET, baseAmount, parameters);
        uint256 amount = oracleModule.getAmount(WETH_ASSET, value, parameters);
        console.log("value: %s", value);
        console.log("amount: %s", amount);
        // if (baseAmount == 0 || FullMath.mulDiv(1500e6, baseAmount, 1e18) == 0) {
        //     assertEq(value, 0);
        //     assertEq(amount, 0);
        //     return;
        // }

        // NOTE I feel that the 'or equal too' component could mask failures. But at very small numbers it is
        //      necessary as rounding causes the numbers to converge.
        assertGe(value, FullMath.mulDiv(1500e6, baseAmount, 1e18)); // Use Uni math to match rounding
        assertLe(amount, baseAmount);
    }
}
