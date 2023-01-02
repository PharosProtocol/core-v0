// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "src/SavingsAccount.sol";
import "src/Storage.sol";

import "openzeppelin-contracts/contracts/utils/math/Math.sol";

struct InstructionSetParameters {
    address collateralAsset;
    uint256 maxLoanDurationHours;
    uint256 loanFeeRatio;
    uint256 hourlyInterestRatio;
    uint256 profitShareRatio;
    uint32[] whitelistedTerminalIds;
}

/**
 * An Instruction Set represents the terms between Lenders and Lendees. InstructionSets can serve
 * multiple Savings Accounts and multiple Terminals. Instruction sets act as the interface between
 * the Savings account, borrowers, liquidators, and terminals.
 * 
 * - Terminals only take 1 type of asset as collateral.
 */
contract InstructionSetTemplate {
    InstructionSetParameters parameters;

    // Savings Account -> Instruction Sets.

    // Borrowers -> Instruction Sets.
    function enter(uint256 amount) public {}
    function exit(bytes32 positionId) public {}

    // Liquidators -> Instruction Sets.
    function exitLiquidate(bytes32 positionId) public {}
    function exitProfit(bytes32 positionId) public {}

    // Terminals -> Instruction Sets.

    // Public helpers.
    function getParameters() public view returns (InstructionSetParameters params) {}
    function getPositions() public view returns (Position[] positions) {}
    function getAllowedTerminals() public view returns (address[] terminals) {}

    // Private helpers.
}

contract UndercollateralizedInstructionSetTemplate is InstructionSetTemplate {}

contract OvercollateralizedInstructionSetTemplate is InstructionSetTemplate {}
