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
import {Path} from "lib/v3-periphery/contracts/libraries/path.sol";
// import "lib/v3-core/contracts/UniswapV3Pool.sol";
import {FullMath} from "lib/v3-core/contracts/libraries/FullMath.sol";

// import {TestUtils} from "test/LibTestUtils.sol";

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "src/libraries/LibUtils.sol";
import {C} from "src/libraries/C.sol";
import {UniswapV3Oracle} from "src/modules/oracle/implementations/UniswapV3Oracle.sol";

contract UniswapV3OracleTest is Test, Module {
    using Path for bytes;

    UniswapV3Oracle public oracleModule;
    uint256 POOL_USDC_AT_BLOCK = 147_000_000e6;
    uint256 POOL_WETH_AT_BLOCK = 80_000e18;
    Asset WETH_ASSET = Asset({standard: ERC20_STANDARD, addr: address(C.WETH), decimals: 18, id: 0, data: ""});

    constructor() {}

    function POOL_INIT_CODE_HASH() external pure returns (bytes32) {
        return PoolAddress.POOL_INIT_CODE_HASH;
    }

    // invoked before each test case is run
    function setUp() public {
        vm.recordLogs();
        // NOTE not compatible on Georli or Sepolia, due to lack of Uni V3 pools.
        // requires fork at known time so valuations are known. uni quote of eth ~= $1,919.37
        vm.createSelectFork(vm.rpcUrl("mainnet"), 17598691); // test begins at end of block.

        oracleModule = new UniswapV3Oracle();
    }

    function test_UniV3Oracle() public {
        // Uniswap v3 USDC:WETH pool - https://info.uniswap.org/#/pools/0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640
        UniswapV3Oracle.Parameters memory params = UniswapV3Oracle.Parameters({
            pathFromEth: abi.encodePacked(C.WETH, uint24(500), C.USDC), // addr, uint24, addr, uint24, addr ...
            pathToEth: abi.encodePacked(C.USDC, uint24(500), C.WETH),
            twapTime: 300
        });
        bytes memory parameters = abi.encode(params);

        // Will fail if POOL_INIT_CODE_HASH does not match chain deployed pool creation bytecode hash.
        // correct hash here: https://github.com/Uniswap/v3-sdk/issues/113
        // oracleModule.verifyParameters(WETH_ASSET, parameters);

        // Nearest txn, but exact values are taken from running this code itself.
        // https://etherscan.io/tx/0xdbb4daef28e55f2d5f56de0aab299e5e488f13ba36313d38ab40914f99b63811
        uint256 value = oracleModule.getResistantValue(2000e6, parameters);
        uint256 spotValue = oracleModule.getSpotValue(2000e6, parameters);
        uint256 amount = oracleModule.getResistantAmount(1e18, parameters);
        // NOTE these test values were pulled from manual runs of the code with human verification.
        console.log("value: %s", value);
        console.log("spot value: %s", spotValue);
        console.log("amount: %s", amount);
        assertEq(value, 1035687345973702558);
        assertEq(spotValue, 1036308913755103976);
        assertEq(amount, 1911822141);
    }

    // NOTE could add fuzzed path with some creativity.
    /// @notice fuzz testing of getCost. Does not check for correctness.
    function testFuzz_UniV3Oracle(uint256 baseAmount) public {
        // Cannot do too much or will experience significant slippage.
        baseAmount = bound(baseAmount, 1000e6, 1_000_000e6);
        // Uniswap v3 USDC:WETH pool - https://info.uniswap.org/#/pools/0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640
        UniswapV3Oracle.Parameters memory params = UniswapV3Oracle.Parameters({
            pathFromEth: abi.encodePacked(C.WETH, uint24(500), C.USDC), // addr, uint24, addr, uint24, addr ...
            pathToEth: abi.encodePacked(C.USDC, uint24(500), C.WETH),
            twapTime: 300
        });
        bytes memory parameters = abi.encode(params);

        uint256 value = oracleModule.getResistantValue(baseAmount, parameters);
        uint256 spotValue = oracleModule.getSpotValue(baseAmount, parameters);
        uint256 newAmount = oracleModule.getResistantAmount(value, parameters);

        uint256 expectedAmount = baseAmount * (C.RATIO_FACTOR - oracleModule.STEP_SLIPPAGE()) ** 2 / C.RATIO_FACTOR ** 2;
        // Matching rounding here is difficult. Uni internal rounding is different that Oracle application of slippage.
        // Use Uni math to match rounding. Fees are round up.
        // uint256 expectedAmount = FullMath.mulDivRoundingUp(
        //     baseAmount, (C.RATIO_FACTOR - oracleModule.STEP_SLIPPAGE()) ** 2, C.RATIO_FACTOR ** 2
        // );

        // AUDIT NOTE seems to no way to exctly match rounding.
        if (newAmount != expectedAmount && newAmount != expectedAmount - 1) {
            console.log("newAmount: %s", newAmount);
            console.log("expectedAmount: %s", expectedAmount);
            revert("newAmount is divergent from expectedAmount");
        }
        // assertEq(newAmount, expectedAmount);

        assertGt(spotValue, value);
    }
}
