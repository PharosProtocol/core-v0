// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import "lib/tractor/Tractor.sol";
import "src/libraries/LibUtil.sol";
import "src/Terminal/IPosition.sol";

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
    address[] loanAsset;
    address[] collateralAsset;
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
    address[] loanAsset;
    address[] collateralAsset;
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
    address loanAsset;
    address collateralAsset;
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
    uint256 minCollateralRatio; // Position value / collateral value
    uint256 durationLimit;
    uint256 loanAmount;
    uint256 collateralAmount;
    ModuleReference assessor;
    ModuleReference rewarder;
    ModuleReference liquidator;
    /* Allowlisted variables */
    address lender;
    address borrower;
    address loanAsset; // how to ensure loanAsset is match to loanOracle? require 1:1 array order matching?
    address collateralAsset; // same q as above
    ModuleReference loanOracle;
    ModuleReference collateralOracle;
    ModuleReference terminal;
    /* Position deployment details */
    address positionAddr;
    uint256 deploymentTime;
}

library LibOrderBook {
    /// @notice Is the position defined by an agreement up for liquidation and not yet kicked
    /// @dev liquidation based on CR or duration limit
    function isLiquidatable(Agreement agreement) public view returns (bool) {
        IPosition position = IPosition(agreement.positionAddr);
        // if (positionValue == 0) return false;

        // If past expiration, liquidatable.
        if (agreement.deploymentTime + agreement.durationLimit > block.timestamp) return true;

        // Position value / collateral value
        uint256 collateralRatio = RATIO_FACTOR * position.getValue()
            / IOracle(agreement.collateralOracle).getValue(agreement.collateralAmount);

        if (collateralRatio < agreement.minCollateralRatio) {
            return true;
        }
        return false;
    }
}
