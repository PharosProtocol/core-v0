// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

library TC {
    // MAINNET
    string internal constant CHAIN_NAME = "mainnet";
    uint256 internal constant BLOCK_NUMBER = 18346434;  
    uint8 internal constant USDC_DECIMALS = 6;
    address internal constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    // address internal constant DAI = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // address internal constant USDT = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    // address internal constant SHIB = address(0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE);
    // address internal constant PEPE = address(0x6982508145454Ce325dDbE47a25d4ec3d2311933);

    // ARBITRUM
    // string internal constant CHAIN_NAME = "arbitrum_one";
    // uint256 internal constant BLOCK_NUMBER = 119412876;
    // uint8 internal constant USDC_DECIMALS = 6;
    // address internal constant USDC = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    // address internal constant USDC = address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8); // bridged

    // // SEPOLIA
    // uint8 internal constant USDC_DECIMALS = 18;
    // address internal constant USDC = address(0x6f14C02Fc1F78322cFd7d707aB90f18baD3B54f5);
}
