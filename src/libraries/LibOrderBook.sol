// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import "lib/tractor/Tractor.sol";
import "src/libraries/LibUtil.sol";

/**
 * @notice Order representing a Lender.
 */
struct Offer {
    address lender;
    /* Ranged variables */
    uint256[2] minCollateralRatio;
    uint256[2] durationLimit;
    uint256[2] loanAmount;
    uint256[2] collateralAmount;
    ModuleReference[2] assessor;
    ModuleReference[2] rewarder;
    ModuleReference[2] liquidator;
    /* Allowlisted variables */
    address[] takers; // if empty, allow any taker
    ModuleReference[] loanOracle;
    ModuleReference[] collateralOracle;
    ModuleReference[] terminal;
}

/**
 * @notice Order representing a Borrower.
 */
struct Request {
    address borrower;
    /* Ranged variables */
    uint256[2] minCollateralRatio;
    uint256[2] durationLimit;
    uint256[2] loanAmount;
    uint256[2] collateralAmount;
    ModuleReference[2] assessor;
    ModuleReference[2] rewarder;
    ModuleReference[2] liquidator;
    /* Allowlisted variables */
    address[] takers; // if empty, allow any taker
    ModuleReference[] loanOracle;
    ModuleReference[] collateralOracle;
    ModuleReference[] terminal;
}

/**
 * @notice Operator defined Position configuration that is compatible with an offer and a request.
 */
struct OrderMatch {
    /* Ranged variables */
    uint256 minCollateralRatio;
    uint256 durationLimit;
    uint256 loanAmount;
    uint256 collateralAmount;
    ModuleReference assessor;
    ModuleReference rewarder;
    ModuleReference liquidator;
    /* Allowlisted variables */
    IndexPair takerIdx;
    IndexPair loanOracle;
    IndexPair collateralOracle;
    IndexPair terminal;
}

/**
 * @notice Position definition is derived from a Match and both Orders.
 * @dev Signed data structure used to store position configuration off chain, reported via events.
 */
struct Agreement {
    /* Ranged variables */
    uint256 minCollateralRatio;
    uint256 durationLimit;
    uint256 loanAmount;
    uint256 collateralAmount;
    ModuleReference assessor;
    ModuleReference rewarder;
    ModuleReference liquidator;
    /* Allowlisted variables */
    address lender;
    address borrower;
    ModuleReference loanOracle;
    ModuleReference collateralOracle;
    ModuleReference terminal;
    /* Position deployment details */
    address addr;
    uint256 deploymentTime;
}
