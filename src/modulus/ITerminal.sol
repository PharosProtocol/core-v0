// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

/*
Terminals could/should be implemented as Minimal Contract Implementations, where a single terminal
contract is a wrapper over a protocol the basically represents a whitelist of allowed actions
for a user to take against that protocol. MCIs can then be spun up for each Position created
through modulend and represents a single position (one user, one loan). The user can then directly
perform supplementary actions with their position (Farm, swap asset, etc), although interactions
like transferring assets or closing the position will still need to be performed through Modulend
via the strictly defined functions shown below.
This will enable several key features:
1. Modularity of positions. User depoloyed assets are not comingled.
2. Ability for terminals to have arbitrarily nuanced interfaces, as long as they support the
    minimal set of features in the standard interface.*/

/**
 * A terminal represents a gateway to deploy capital in a specific positon. Every terminal,
 * regargless of attached protocol or positon, must implement this interface. Term Sheets are able to interact
 * with terminals using this interface without any knowledge of the underlying implementation.
 *
 * The asset that the position was entered with must be used for valuation and exiting.
 *
 * - Owner is Modulend contract.
 * - Each terminal can use only 1 asset as an input and output.
 */
interface ITerminal {
    // Asset used to interface with the terminal, regardless of position.
    // address interfaceAsset;

    // Modulon -> Terminal.
    // Deploy assets within the terminal as a new position.
    // Assumes assets have already been delivered to the terminal.
    function enter(uint256 amount) external returns (uint32 positionId); // ModulusOnly

    // Remove value from position(s) and return as interfaceAsset. If amount(s) is 0 exit full positon.
    function exit(uint32 positionId, uint256 amount) external; // ModulusOnly

    // Public Helpers.
    function getAllowedAssets() external view returns (address);
    function getPositionValue(uint32 id) external view returns (address asset, uint256 amount);
}
