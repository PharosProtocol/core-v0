// SPDX-License-Identifier: MIT
// solhint-disable

pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import {console} from "@forge-std/console.sol";
import "@uni-v3-periphery/libraries/PoolAddress.sol";
import {Path} from "@uni-v3-periphery/libraries/path.sol";

import {C} from "src/libraries/C.sol";
import {UniswapV3Oracle} from "src/modules/oracle/implementations/UniswapV3Oracle.sol";

contract UniswapV3OracleTest is Test {
    using Path for bytes;

    UniswapV3Oracle public oracleModule;

    constructor() {}

    function POOL_INIT_CODE_HASH() external pure returns (bytes32) {
        // Will fail if POOL_INIT_CODE_HASH does not match chain deployed pool creation bytecode hash.
        // correct hash here: https://github.com/Uniswap/v3-sdk/issues/113
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
            twapTime: 300,
            stepSlippage: uint64(C.RATIO_FACTOR / 200)
        });
        bytes memory parameters = abi.encode(params);

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
            twapTime: 300,
            stepSlippage: uint64(C.RATIO_FACTOR / 200)
        });
        bytes memory parameters = abi.encode(params);

        uint256 value = oracleModule.getResistantValue(baseAmount, parameters);
        uint256 spotValue = oracleModule.getSpotValue(baseAmount, parameters);
        uint256 newAmount = oracleModule.getResistantAmount(value, parameters);

        uint256 expectedAmount = (baseAmount * (C.RATIO_FACTOR - params.stepSlippage) ** 2) / C.RATIO_FACTOR ** 2;
        // Matching rounding here is difficult. Uni internal rounding is different that Oracle application of slippage.
        // Use Uni math to match rounding. Fees are round up.
        // uint256 expectedAmount = FullMath.mulDivRoundingUp(
        //     baseAmount, (C.RATIO_FACTOR - params.params.stepSlippage) ** 2, C.RATIO_FACTOR ** 2
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
