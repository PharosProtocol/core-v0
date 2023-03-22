// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

// import {IOracle} from "src/libraries/oracle/IOracle.sol";
// import {OracleParameters} from "src/libraries/LibOracle.sol";

// // NOTE yes, this would be cheaper by allowing an int to be set directly for the position, but is this really such an
// //      important use case that the entire design should be altered? i don't think so.

// interface IStaticPriceOracle is IOracle {
//     function decodeParameters(OracleParameters calldata oracleParams)
//         external
//         pure
//         returns (Parameters memory params);
// }

// struct Parameters {
//     address asset;
//     uint256 value;
// }

// /*
//  * This is a contract that represents one method of computing asset prices.
//  * Its computation will differ for each set of parameters provided.
//  * Modulus will interact directly with the clone using only the standard functions.
//  */
// contract StaticPriceOracle is IStaticPriceOracle {
//     function decodeParameters(OracleParameters calldata oracleParams) public pure returns (Parameters memory params) {
//         params.asset = oracleParams.asset;
//         params.value = abi.decode(oracleParams.instanceParams, (uint256));
//     }

//     /// @dev no illegal parameters possible within the type constraints.
//     function verifyParameters(OracleParameters calldata) external pure override {
//         return;
//     }

//     /// @dev ignore amount parameter
//     function getValue(uint256 amount, OracleParameters calldata oracleParams) external pure returns (uint256) {
//         return amount * decodeParameters(oracleParams).value; // rounding?
//     }

//     function getAmount(uint256 value, OracleParameters calldata oracleParams) external pure returns (uint256) {
//         return value * decodeParameters(oracleParams).value; // rounding?
//     }
// }
