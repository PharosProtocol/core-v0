// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {C} from "src/C.sol";
import "src/LibUtil.sol";
import "lib/tractor/Tractor.sol";
import "src/interfaces/IPosition.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";

struct IndexPair {
    uint128 offer;
    uint128 request;
}

struct ModuleReference {
    address addr;
    bytes parameters;
}
    
/// @notice terms shared between Offers and Requests.
struct Order {
    uint256[] minLoanAmounts; // idx parity with loanAssets
    Asset[] loanAssets;
    Asset[] collAssets;
    address[] takers;
    uint256 maxDuration;
    uint256 minCollateralRatio;
    // Modules
    ModuleReference account;
    ModuleReference assessor;
    ModuleReference liquidator;
    ModuleReference[] loanOracles;
    ModuleReference[] collateralOracles;
    address[] factories;
    // Sided config
    bool isOffer;
    BorrowerConfig borrowerConfig; // Only set in Requests
}

struct BorrowerConfig {
    uint256 initCollateralRatio; // Borrower chooses starting health.
    bytes positionParameters; // Should lenders be allowing specified parameters?
}

/// @notice Taker defined Position configuration that is compatible with an offer or a request.
struct Fill {
    uint256 loanAmount; // should be valid with both minFillRatios and account balances
    uint256 takerIdx; // ignored if no taker allowlist.
    uint256 loanAssetIdx; // need to verify with the oracle
    uint256 collAssetIdx; // need to verify with the oracle
    uint256 loanOracleIdx;
    uint256 collateralOracleIdx;
    uint256 factoryIdx;
    // Sided config
    bool isOfferFill;
    BorrowerConfig borrowerConfig; // Only set when filling Offers
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
    Asset collAsset;
    uint256 minCollateralRatio; // Position value / collateral value
    uint256 maxDuration;
    ModuleReference lenderAccount;
    ModuleReference borrowerAccount;
    ModuleReference assessor;
    ModuleReference liquidator;
    ModuleReference loanOracle;
    ModuleReference collateralOracle;
    address factory;
    ModuleReference position; // addr set by bookkeeper.
    uint256 deploymentTime; // set by bookkeeper
}

library LibBookkeeper {
    /// @notice Is the position defined by an agreement up for liquidation and not yet kicked
    /// @dev liquidation based on CR or duration limit
    function isLiquidatable(Agreement memory agreement) public view returns (bool) {
        IPosition position = IPosition(agreement.position.addr);
        // if (positionValue == 0) return false;

        // If past expiration, liquidatable.
        if (agreement.deploymentTime + agreement.maxDuration > block.timestamp) return true;

        // NOTE this looks expensive. could have the caller pass in the expected position value and exit if not enough
        //      assets at exit time
        // (position value - cost) / collateral value
        uint256 exitAmount = position.getExitAmount(agreement.position.parameters);
        uint256 cost = IAssessor(agreement.assessor.addr).getCost(agreement);
        if (cost > exitAmount) {
            return true;
        }
        uint256 adjustedPositionAmount = exitAmount - cost;
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
