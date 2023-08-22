// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IPosition} from "src/interfaces/IPosition.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {C} from "src/libraries/C.sol";
import {Asset, ETH_STANDARD, LibUtils, PluginRef} from "src/libraries/LibUtils.sol";

struct IndexPair {
    uint128 offer;
    uint128 request;
}

/// @notice terms shared between Offers and Requests.
struct Order {
    uint256[] minLoanAmounts; // idx parity with loanAssets
    Asset[] loanAssets;
    Asset[] collAssets;
    address[] fillers;
    uint256 maxDuration;
    uint256 minCollateralRatio;
    // Plugins
    PluginRef account;
    PluginRef assessor;
    PluginRef liquidator;
    PluginRef[] loanOracles;
    PluginRef[] collOracles;
    PluginRef loanFreighter;
    PluginRef collFreighter;
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
    PluginRef account;
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
    PluginRef lenderAccount;
    PluginRef borrowerAccount;
    PluginRef assessor;
    PluginRef liquidator;
    PluginRef loanOracle;
    PluginRef collOracle;
    address factory;
    PluginRef position; // addr set by bookkeeper.
    uint256 deploymentTime; // set by bookkeeper
}

library LibBookkeeper {
    // NOTE cannot verify order, bc they are signed off chain.
    // /// @notice verify that an order is validly configured.
    // function verifyOrder(Order calldata order) internal pure {
    // }

    /// @notice verify that a fill is valid for an order.
    /// @dev Reverts with reason if not valid.
    function verifyFill(Fill calldata fill, Order memory order) internal pure {
        BorrowerConfig memory borrowerConfig;
        if (!order.isOffer) {
            require(!fill.isOfferFill, "offer fill of offer");
            borrowerConfig = order.borrowerConfig;
        } else {
            require(fill.isOfferFill, "request fill of request");
            borrowerConfig = fill.borrowerConfig;
        }

        // NOTE SECURITY should ensure filling bytes are reasonable size to prevent gas griefing

        require(fill.loanAmount >= order.minLoanAmounts[fill.loanAssetIdx], "loanAmount too small");
        require(borrowerConfig.initCollateralRatio >= order.minCollateralRatio, "initCollateralRatio too small");

        // NOTE this would be the right place to verify modules are compatible with agreement. Current
        //      design allows users to make invalid combinations and leaves compatibility checks up to
        //      UI/user. This is not great but fine because both users must explicitly agree to terms.
    }
        
    /// @dev assumes compatibility between match, offer, and request already verified.
    /// @dev does not fill position address, as it is not known until deployment.
    function agreementFromOrder(
        Fill calldata fill,
        Order memory order
    ) internal pure returns (Agreement memory agreement) {
        // AUDIT would this be more efficient in a single set statement, to avoid lots of zero -> non-zero changes?
        //       i.e. agreement = Agreement({.....});
        agreement.maxDuration = order.maxDuration;
        agreement.assessor = order.assessor;
        agreement.liquidator = order.liquidator;
        agreement.minCollateralRatio = order.minCollateralRatio;

        agreement.loanAsset = order.loanAssets[fill.loanAssetIdx];
        agreement.loanOracle = order.loanOracles[fill.loanOracleIdx];
        agreement.collAsset = order.collAssets[fill.collAssetIdx];
        agreement.collOracle = order.collOracles[fill.collOracleIdx];
        agreement.factory = order.factories[fill.factoryIdx];

        agreement.loanAmount = fill.loanAmount;
    }

    /// @notice Is the position defined by an agreement up for liquidation and not yet kicked
    /// @dev liquidation based on CR or duration limit
    function isLiquidatable(Agreement memory agreement) internal view returns (bool) {
        IPosition position = IPosition(agreement.position.addr);
        // if (positionValue == 0) return false;

        // If past expiration, liquidatable.
        if (block.timestamp > agreement.deploymentTime + agreement.maxDuration) return true;

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
            agreement.collAmount, // TODO change to be dynamic balance in contract?
            agreement.collOracle.parameters
        );

        uint256 collateralRatio = (C.RATIO_FACTOR * outstandingValue) / collValue;

        if (collateralRatio < agreement.minCollateralRatio) {
            return true;
        }
        return false;
    }
}
