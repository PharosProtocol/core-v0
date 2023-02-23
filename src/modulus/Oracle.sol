// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

/*
 * Oracles are deployed in independent contracts. They should be stateless and match the interface specification
 * here.
 */
interface IOracle {
    /*
     * Return value of asset in USDC.
     */
    function getValue(bytes calldata data) external view returns (uint256);
}
