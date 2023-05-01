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

/// @notice terms shared between Offers and Requests.
struct Order {
    uint256[] minLoanAmounts; // idx parity with loanAssets
    Asset[] loanAssets;
    Asset[] collateralAssets;
    address[] takers;
    uint256 maxDuration;
    uint256 minCollateralRatio;
    // Modules
    ModuleReference account;
    ModuleReference assessor;
    ModuleReference liquidator;
    ModuleReference[] loanOracles;
    ModuleReference[] collateralOracles;
    address[] terminals;
    // Sided config
    bool isOffer;
    BorrowerConfig borrowerConfig; // Only set in Requests
}

/**
 * @notice Order representing a Lender.
 */
// struct OfferConfig {}

/**
 * @notice Order representing a Borrower.
 */
struct RequestConfig {
    uint256 initCollateralRatio; // Borrower chooses starting health.
    bytes positionParameters; // Should lenders be allowing specified parameters?
}

/// @notice Taker defined Position configuration that is compatible with an offer or a request.
struct Fill {
    uint256 loanAmount; // should be valid with both minFillRatios and account balances
    uint256 takerIdx; // Do not use if no taker allowlist.
    uint256 loanAssetIdx; // need to verify with the oracle
    uint256 collateralAssetIdx; // need to verify with the oracle
    uint256 loanOracleIdx;
    uint256 collateralOracleIdx;
    uint256 terminalIdx;
    // Sided config
    bool isOfferFill;
    BorrowerConfig borrowerConfig; // Only set when filling Offers
}

struct BorrowerConfig {
    uint256 initCollateralRatio; // Borrower chooses starting health.
    bytes positionParameters; // Should lenders be allowing specified parameters?
}
// struct LenderConfig {}

/**
 * @notice Position definition is derived from a Match and both Orders.
 * @dev Signed data structure used to store position configuration off chain, reported via events.
 */
struct Agreement {
    // uint256 bookkeeperVersion;
    uint256 loanAmount;
    uint256 collateralAmount;
    Asset loanAsset;
    Asset collateralAsset;
    uint256 minCollateralRatio; // Position value / collateral value
    uint256 maxDuration;
    ModuleReference lenderAccount;
    ModuleReference borrowerAccount;
    ModuleReference assessor;
    ModuleReference liquidator;
    ModuleReference loanOracle;
    ModuleReference collateralOracle;
    ModuleReference position;
    // Position deployment details, set by bookkeeper.
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
        if (agreement.deploymentTime + agreement.maxDuration > block.timestamp) return true;

        // NOTE this looks expensive. could have the caller pass in the expected position value and exit if not enough
        //      assets at exit time
        // (position value - cost) / collateral value
        uint256 adjustedPositionAmount = position.getExitAmount(agreement.position.parameters)
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
