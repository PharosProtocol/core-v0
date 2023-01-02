// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * A terminal represents a gateway to deploy capital in a specific positon. Every terminal,
 * regargless of attached protocol or positon, must implement this interface. Instruction Sets are able to interact
 * with terminals using this interface without any knowledge of the underlying implementation.
 * 
 * - Owner is Modulend contract.
 * - Each terminal can take only 1 asset as an input.
 */
contract TerminalTemplate is Ownable {
    // Public calls.
    function getPositionValue(bytes32 id) public view returns (int256 value) {}
    function getPositions() public view returns (Position[] positions) {}

    // Calls from Modulon Instruction Sets.
    function enter(id positionId, uint256 amount) public onlyOwner {}
    function exit(bytes32 positionId) public onlyOwner {}
    function exitProfit(bytes32 positionId, uint256 percentage) public onlyOwner {}
}
