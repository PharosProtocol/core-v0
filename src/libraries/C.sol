// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

library C {
    uint256 internal constant RATIO_FACTOR = 1e18;

    // Mainnet and Goerli
    address internal constant UNI_V3_FACTORY = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    address public constant UNI_V3_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    // MAINNET ADDRESSES
    address internal constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // GOERLI ADDRESSES
    // address internal constant USDC = address(0x32dBd8db20Bfe5506104119EdCC89bc3D8C5c3Ee);
    // address internal constant WETH = address(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    bytes32 internal constant BOOKKEEPER_ROLE = keccak256("BOOKKEEPER_ROLE");
    bytes32 internal constant ADMIN_ROLE = 0x00;
}
