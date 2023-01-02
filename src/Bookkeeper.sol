// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

/**
 * The Bookkeeper holds Modulon state that is shared between multiple components, including terminals.
 */
contract Bookkeeper {
    mapping(address => Position[]) public positions;

    function getPosition(uint32 positonId) public view returns (Position position) {}
}
