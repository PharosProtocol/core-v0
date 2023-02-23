// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

// Deployment cost ~110k gas.

/// Adheres to IOracle located in "src/modulus/Oracle.sol"
// NOTE: Is ok to define View Interface function as pure here?
contract UsdcOracle {
    function getValue(bytes calldata) external pure returns (uint256) {
        return 1;
    }
}
