// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "openzeppelin-contracts/contracts/access/IAccessControl.sol";

/**
 * A terminal represents a gateway to deploy capital in a specific positon. Every terminal,
 * regargless of attached protocol or positon, must implement this interface. Term Sheets are able to interact
 * with terminals using this interface without any knowledge of the underlying implementation.
 * 
 * - Owner is Modulend contract.
 * - Each terminal can use only 1 asset as an input and output.
 */
interface ITerminal is IAccessControl { //Q necessary to specify IAccessControl here?

    // Asset used to interface with the terminal, regardless of position.
    // address interfaceAsset;

    // Modulon -> Terminal.
    // Deploy assets within the terminal as a new position.
    // Assumes assets have already been delivered to the terminal.
    function enter(uint256 amount) external returns(uint32 positionId); // onlyOwner
    
    // Remove value from position(s) and return as interfaceAsset. If amount(s) is 0 exit full positon.
    function exit(uint32 positionId, uint256 amount) external; // onlyOwner
    function exitMultiple(uint32[] calldata positionIds, uint256[] calldata amounts) external; // onlyOwner
    
    // Exit all lender profit across all positions and send funds to Modulon contract.
    // Do nothing if no profits to claim.
    function exitProfit() external returns (uint256 amount); // onlyOwner

    // Public Helpers.
    function getInterfaceAsset() external view returns (address);
    function getPositionValue(uint32 id) external view returns (int256 value);
}
