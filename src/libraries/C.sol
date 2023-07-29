// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

library C {
    uint256 internal constant RATIO_FACTOR = 1e18;

    uint256 internal constant ETH_DECIMALS = 18;

    // Mainnet and Goerli
    address internal constant UNI_V3_FACTORY = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    address internal constant UNI_V3_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    // MAINNET ADDRESSES
    uint8 internal constant BLOCK_TIME = 12; // SECURITY block time may change with chain updates.
    uint8 internal constant USDC_DECIMALS = 6;
    address internal constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address internal constant DAI = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address internal constant USDT = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address internal constant SHIB = address(0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE);
    address internal constant PEPE = address(0x6982508145454Ce325dDbE47a25d4ec3d2311933);

    // // GOERLI ADDRESSES
    // address internal constant USDC = address(0x32dBd8db20Bfe5506104119EdCC89bc3D8C5c3Ee);
    // address internal constant WETH = address(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    // // SEPOLIA ADDRESSES
    // uint8 internal constant USDC_DECIMALS = 18;
    // address internal constant USDC = address(0x6f14C02Fc1F78322cFd7d707aB90f18baD3B54f5);
    // address internal constant WETH = address(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9);

    bytes32 internal constant BOOKKEEPER_ROLE = keccak256("BOOKKEEPER_ROLE");
    bytes32 internal constant ADMIN_ROLE = 0x00;
}
