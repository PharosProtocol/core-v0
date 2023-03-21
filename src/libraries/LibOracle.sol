// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

// NOTE is it necessary to verify that these types of structs are well formed in calldata? is it possible to
//      pass data that appears to fit this format but is actually hostile?

struct OracleParameters {
    address asset;
    bytes instanceParams;
}
