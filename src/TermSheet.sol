// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "src/Bookkeeper.sol";
import "src/SavingsAccount.sol";
import "src/Storage.sol";
import "src/ITemplate.sol";

import "openzeppelin-contracts/contracts/utils/math/Math.sol";


/**
 * a term Sheet represents the terms between Lenders and Lendees. Instructions can serve
 * multiple supply accounts, borrow accounts, and Terminals. Term sheets act as the interface between
 * the Savings account, borrowers, liquidators, and terminals.
 *
 * - Terminals only take 1 type of asset as collateral.
 * - Assume that Term Sheet Asset type and Terminal Asset type are the same.
 * - Asset must be Eth or an ERC20.
 * - Collateral asset must be same as loan asset.
 * - Do not deploy collateral, unless same as loan asset.
 */
struct TermSheet {
    // bytes32 id; // redundant, since set cannot be accessed without id.
    uint32 version;
    // Collateral and terminal asset type.
    // address asset; // redundant, as can be derived from Terminal, but offers gas savings?
    address[] loanAssets;
    address[] collateralAssets;
    // How to value any asset this Term Sheet interacts with (loan or collateral).
    mapping(asset => bytes32) valuators;
    address[] allowedTerminals;
    /* Tweakable performance parameters */
    uint256 duration; // seconds
    uint256 utilizationThreshold;
    uint256 interestRate; // per second
    uint256 loanFee;
    uint256 profitShareRatio;
    uint256 maxCollateralizationRatio;
    uint256 liquidatorReward;
}