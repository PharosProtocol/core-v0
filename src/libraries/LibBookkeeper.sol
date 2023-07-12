// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IPosition} from "src/interfaces/IPosition.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {C} from "src/libraries/C.sol";
import {Asset, ETH_STANDARD, LibUtils} from "src/libraries/LibUtils.sol";

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
    address[] fillers;
    uint256 maxDuration;
    uint256 minCollateralRatio;
    // Modules
    ModuleReference account;
    ModuleReference assessor;
    ModuleReference liquidator;
    ModuleReference[] loanOracles;
    ModuleReference[] collOracles;
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
    ModuleReference account;
    uint256 loanAmount; // should be valid with both minFillRatios and account balances
    uint256 takerIdx; // ignored if no taker allowlist.
    uint256 loanAssetIdx; // need to verify with the oracle
    uint256 collAssetIdx; // need to verify with the oracle
    uint256 loanOracleIdx;
    uint256 collOracleIdx;
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
    uint256 collAmount;
    Asset loanAsset;
    Asset collAsset;
    uint256 minCollateralRatio; // Position value / collateral value
    uint256 maxDuration;
    ModuleReference lenderAccount;
    ModuleReference borrowerAccount;
    ModuleReference assessor;
    ModuleReference liquidator;
    ModuleReference loanOracle;
    ModuleReference collOracle;
    address factory;
    ModuleReference position; // addr set by bookkeeper.
    uint256 deploymentTime; // set by bookkeeper
}

library LibBookkeeper {
    /// @notice Is the position defined by an agreement up for liquidation and not yet kicked
    /// @dev liquidation based on CR or duration limit
    function isLiquidatable(Agreement memory agreement) internal view returns (bool) {
        IPosition position = IPosition(agreement.position.addr);
        // if (positionValue == 0) return false;

        // If past expiration, liquidatable.
        if (block.timestamp > agreement.deploymentTime + agreement.maxDuration) return true;

        // NOTE this looks expensive. could have the caller pass in the expected position value and exit if not enough
        //      assets at exit time
        // (position value - cost) / collateral value
        uint256 exitAmount = position.getCloseAmount(agreement.position.parameters);
        (Asset memory costAsset, uint256 cost) = IAssessor(agreement.assessor.addr).getCost(agreement, exitAmount);

        uint256 outstandingValue;
        if (LibUtils.isValidLoanAssetAsCost(agreement.loanAsset, costAsset)) {
            if (cost > exitAmount) return true;
            outstandingValue = IOracle(agreement.loanOracle.addr).getSpotValue(
                exitAmount - cost,
                agreement.loanOracle.parameters
            );
        } else if (costAsset.standard == ETH_STANDARD) {
            uint256 positionValue = IOracle(agreement.loanOracle.addr).getSpotValue(
                exitAmount,
                agreement.loanOracle.parameters
            );
            if (positionValue > cost) return true;
            outstandingValue = positionValue - cost;
        } else {
            revert("isLiquidatable: invalid asset");
        }
        uint256 collValue = IOracle(agreement.collOracle.addr).getSpotValue(
            agreement.collAmount,
            agreement.collOracle.parameters
        );

        uint256 collateralRatio = (C.RATIO_FACTOR * outstandingValue) / collValue;

        if (collateralRatio < agreement.minCollateralRatio) {
            return true;
        }
        return false;
    }
}
