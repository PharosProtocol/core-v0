// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

/**
 * A term Sheet represents the terms between Lenders and Borrowers. Term sheets are entirely agnostic and unaware of
 * supply accounts, borrow accounts, and Terminals, which enables unrestricted reuseability. Term sheets define the
 * relationship between the Savings account, borrowers, liquidators, and terminals.
 * If an oracle is not defined for an asset the asset cannot be used with these Terms. Asset restrictions are set in
 * Offer and Request Accounts.
 *
 * - Asset must be an ERC20.
 * - Do not deploy collaterals.
 */
struct TermSheet {
    // How to value any asset this Term Sheet interacts with.
    mapping(address => bytes32) oracles;
    /* Operational Parameters */
    uint256 maxCollateralizationRatio;
    uint256 liquidatorReward;
    /* Cost Parameters */
    uint256 maxDuration; // seconds
    uint256 interestRateRatio; // per second
    uint256 loanFee;
    uint256 profitShareRatio;
}
