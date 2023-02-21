// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

library C {
    uint256 internal constant RATIO_BASE = 1e18;
    uint256 internal constant OWNERSHIP_BASE = 1e18;

    uint256 internal constant SECS_IN_HOUR = 3600;

    address internal constant MODULEND_ADDR = address(100);

    address internal constant UNI_V3_POOL_USDC_ETH = address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);

    uint32 internal constant CURVE_VALUATOR_TYPE_ID = 1;
}
