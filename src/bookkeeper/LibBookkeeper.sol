// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {C} from "src/C.sol";
import "src/LibUtil.sol";
import "lib/tractor/Tractor.sol";
import "src/Terminal/IPosition.sol";
import {IOracle} from "src/modules/oracle/IOracle.sol";
import {IAssessor} from "src/modules/assessor/IAssessor.sol";

struct IndexPair {
    uint128 offer;
    uint128 request;
}

struct ModuleReference {
    address addr;
    bytes parameters;
}

// NOTE Both Offer and Request offer extremely high dimensionality in handling sets of assets. This could be
//      simplified by removing that functionality. Unclear if it is something users would actually use.

/**
 * @notice Order representing a Lender.
 */
struct Offer {
    ModuleReference lenderAccount;
    uint256[] loanableAmounts;
    uint256 minFillRatio; // allows partial fills, prevents griefing
    /* Ranged variables */
    uint256 maxDurationUpperLimit;
    uint256 minCollateralRatioLowerLimit;
    ModuleReference assessorLowerLimit;
    ModuleReference liquidatorLowerLimit;
    /* Allowlisted variables */
    Asset[] loanAssets;
    Asset[] collateralAssets;
    address[] takers; // if empty, allow any taker
    ModuleReference[] loanOracles;
    ModuleReference[] collateralOracles;
    address[] terminals;
}

/**
 * @notice Order representing a Borrower.
 */
struct Request {
    ModuleReference borrowerAccount;
    uint256 initCollateralRatio;
    uint256[] collateralableAmounts; // Arranged in sync with collateralAssets
    uint256 minFillRatio; // allows partial fills, prevents griefing
    /* Ranged variables */
    uint256 maxDurationLowerLimit;
    uint256 minCollateralRatioUpperLimit;
    ModuleReference assessorUpperLimit;
    ModuleReference liquidatorUpperLimit;
    /* Allowlisted variables */
    Asset[] loanAssets;
    Asset[] collateralAssets;
    address[] takers; // if empty, allow any taker
    ModuleReference[] loanOracles;
    ModuleReference[] collateralOracles;
    ModuleReference[] terminals;
}

/**
 * @notice Operator defined Position configuration that is compatible with an offer and a request.
 */
struct OrderMatch {
    /* Ranged variables */
    // uint256 minCollateralRatio;
    // uint256 durationLimit;
    uint256 loanAmount; // should be valid with both minFillRatios and account balances
    // uint256 collateralAmount;
    // ModuleReference assessor;
    // ModuleReference liquidator;
    /* Allowlisted variables */
    IndexPair takerIdx;
    IndexPair loanAsset; // need to verify with the oracle
    IndexPair collateralAsset; // need to verify with the oracle
    IndexPair loanOracle;
    IndexPair collateralOracle;
    IndexPair terminal;
}

/**
 * @notice Position definition is derived from a Match and both Orders.
 * @dev Signed data structure used to store position configuration off chain, reported via events.
 */
struct Agreement {
    uint256 bookkeeperVersion;
    uint256 loanAmount;
    uint256 collateralAmount;
    uint256 minCollateralRatio; // Position value / collateral value
    uint256 durationLimit;
    ModuleReference assessor;
    ModuleReference liquidator;
    //
    ModuleReference lenderAccount;
    ModuleReference borrowerAccount;
    Asset loanAsset; // how to ensure loanAsset is match to loanOracle? require 1:1 array order matching? <- by verifying oracle does not return price 0 for the asset
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
        uint256 adjustedPositionAmount = position.getExitAmount(agreement.terminal.parameters)
            - IAssessor(agreement.assessor.addr).getCost(agreement);
        uint256 collateralRatio = C.RATIO_FACTOR
            * IOracle(agreement.loanOracle.addr).getValue(
                agreement.loanAsset, adjustedPositionAmount, agreement.loanOracle.parameters
            )
            / IOracle(agreement.collateralOracle.addr).getValue(
                agreement.loanAsset, agreement.collateralAmount, agreement.collateralOracle.parameters
            );

        if (collateralRatio < agreement.minCollateralRatio) {
            return true;
        }
        return false;
    }
}
