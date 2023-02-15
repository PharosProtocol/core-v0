// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

/* 
 * Not necessary now, unclear if will ever be necessary.
 */
abstract contract Swapper {
    // bytes32 id; // redundant, used to access.
    address asset;

    constructor(address calldata asset) {
        asset = asset;
    }

    // Function that returns value of asset in USDC.
    function swap() public virtual returns (uint256);
}
