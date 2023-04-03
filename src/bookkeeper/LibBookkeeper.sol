// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "src/C.sol";
import "src/LibUtil.sol";
import "lib/tractor/Tractor.sol";
import "src/Terminal/IPosition.sol";
import {IOracle} from "src/modules/oracle/IOracle.sol";

/**
 * @notice Order representing a Lender.
 */
struct Offer {
    ModuleReference lenderAccount;
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
    Asset[] loanAsset;
    Asset[] collateralAsset;
    ModuleReference[] loanOracle;
    ModuleReference[] collateralOracle;
    ModuleReference[] terminal;
}

/**
 * @notice Order representing a Borrower.
 */
struct Request {
    ModuleReference borrowerAccount;
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
    Asset[] loanAsset;
    Asset[] collateralAsset;
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
    Asset loanAsset;
    Asset collateralAsset;
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
    ModuleReference lenderAccount;
    ModuleReference borrowerAccount;
    Asset loanAsset; // how to ensure loanAsset is match to loanOracle? require 1:1 array order matching?
    Asset collateralAsset; // same q as above
    ModuleReference loanOracle;
    ModuleReference collateralOracle;
    ModuleReference terminal;
    /* Position deployment details */
    address positionAddr;
    uint256 deploymentTime;
}

library LibBookkeeper {
    /// @notice Is the position defined by an agreement up for liquidation and not yet kicked
    /// @dev liquidation based on CR or duration limit
    function isLiquidatable(Agreement memory agreement) public view returns (bool) {
        IPosition position = IPosition(agreement.positionAddr);
        // if (positionValue == 0) return false;

        // If past expiration, liquidatable.
        if (agreement.deploymentTime + agreement.durationLimit > block.timestamp) return true;

        // NOTE this looks expensive. could have the caller pass in the expected position value and exit if not enough
        //      assets at exit time
        // (position value - cost) / collateral value
        uint256 adjustedPositionAmount =
            position.getAmount(agreement.terminal.parameters) - IAssessor(agreement.assessor.addr).getCost(agreement);
        uint256 collateralRatio = C.RATIO_FACTOR
            * IOracle(agreement.loanOracle.addr).getValue(adjustedPositionAmount, agreement.loanOracle.parameters)
            / IOracle(agreement.collateralOracle.addr).getValue(
                agreement.collateralAmount, agreement.collateralOracle.parameters
            );

        if (collateralRatio < agreement.minCollateralRatio) {
            return true;
        }
        return false;
    }
}
