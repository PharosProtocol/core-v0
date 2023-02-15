// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "src/ITerminal.sol";

struct Position {
    uint32 positionId;
    address borrowerId;
    address terminalAddress;
    // uint256 creationTime;
    uint256 inputAmount; // Is this ok type for all reasonable token Decimal configurations?
    uint256 lastProfitTime;
    uint256 liquidationThreshholdAmount;
}

/**
 * The Bookkeeper holds Modulon state that is shared between multiple components, including terminals.
 */
contract Bookkeeper {
    mapping(address => Position[]) public activePositions;

    function getPosition(uint32 positonId) public view returns (Position memory position) {}
    function getTerminalPositions(address terminalAddress) public view returns (Position[] memory positions) {}

    // Take the lender profit from all positions in a terminal and distribute among lenders and sender.
    function takeTerminalProfit(address terminalAddress) {
        ITerminal terminal = new ITerminal(terminalAddress);
        // Exit profit from terminal position and send to Modulon contract as interface asset.
        terminal.exitProfit();

        // Reward caller?

        // Distribute profits to lenders.

    }
}
