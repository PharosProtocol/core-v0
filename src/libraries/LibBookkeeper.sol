// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IPosition} from "src/interfaces/IPosition.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {C} from "src/libraries/C.sol";
import {LibUtils} from "src/libraries/LibUtils.sol";

struct IndexPair {
    uint128 offer;
    uint128 request;
}

struct PluginReference {
    address addr;
    bytes parameters;
}

/// @notice terms shared between Offers and Requests.
struct Order {
    uint256[] minLoanAmounts; // idx parity with loanAssets
    bytes[] loanAssets;
    bytes[] collAssets;
    address[] fillers;
    uint256 maxDuration;
    uint256 minCollateralRatio;
    // Plugins
    PluginReference account;
    PluginReference assessor;
    PluginReference liquidator;
    PluginReference[] loanOracles;
    PluginReference[] collOracles;
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
    PluginReference account;
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
    bytes loanAsset;
    bytes collAsset;
    uint256 minCollateralRatio; // Position value / collateral value
    uint256 maxDuration;
    PluginReference lenderAccount;
    PluginReference borrowerAccount;
    PluginReference assessor;
    PluginReference liquidator;
    PluginReference loanOracle;
    PluginReference collOracle;
    address factory;
    PluginReference position; // addr set by bookkeeper.
    uint256 deploymentTime; // set by bookkeeper
}

library LibBookkeeper {
    /// @notice verify that a fill is valid for an order.
    /// @dev Reverts with reason if not valid.
    function verifyFill(Fill calldata fill, Order memory order) internal view {
        BorrowerConfig memory borrowerConfig;
        if (!order.isOffer) {
            require(!fill.isOfferFill, "offer fill of offer");
            borrowerConfig = order.borrowerConfig;
        } else {
            require(fill.isOfferFill, "request fill of request");
            borrowerConfig = fill.borrowerConfig;
        }

        require(fill.loanAmount >= order.minLoanAmounts[fill.loanAssetIdx], "loanAmount too small");
        require(borrowerConfig.initCollateralRatio >= order.minCollateralRatio, "initCollateralRatio too small");

        // NOTE this would be the right place to verify modules are compatible with agreement. Current
        //      design allows users to make invalid combinations and leaves compatibility checks up to
        //      UI/user. This is not great but fine because both users must explicitly agree to terms.

        // NOTE v0.1 TESTING RESTRICTIONS.
        //      THESE ARE TEMPORARY.
        require(
            IOracle(order.loanOracles[fill.loanOracleIdx].addr).getSpotValue(
                fill.loanAmount,
                order.loanOracles[fill.loanOracleIdx].parameters
            ) <= 1e18 / 10,
            "calm down fren. we just testing. keep loan value at or below 0.1 ETH"
        );
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

    // NOTE should make this public, without increasing lib gas cost
    /// @notice Is the position defined by an agreement up for liquidation and not yet kicked
    /// @dev liquidation based on CR or duration limit
    function isLiquidatable(Agreement memory agreement) internal view returns (bool) {
        IPosition position = IPosition(agreement.position.addr);
        // if (positionValue == 0) return false;

        // If past expiration, liquidatable.
        if (block.timestamp > agreement.deploymentTime + agreement.maxDuration) return true;

        uint256 exitAmount = position.getCloseAmount(agreement.position.parameters);
        ( uint256 cost) = IAssessor(agreement.assessor.addr).getCost(agreement, exitAmount);

        uint256 outstandingValue;
        outstandingValue = IOracle(agreement.loanOracle.addr).getSpotValue(
                exitAmount - cost,
                agreement.loanOracle.parameters
            );

        uint256 collValue = IOracle(agreement.collOracle.addr).getSpotValue(
            agreement.collAmount,
            agreement.collOracle.parameters
        );

        // NOTE WARNING FUNDERBRKER - CR calc can create negative numbers. This code cannot deal. Update.

        uint256 collateralRatio = (C.RATIO_FACTOR * outstandingValue) / collValue;

        if (collateralRatio < agreement.minCollateralRatio) {
            return true;
        }
        return false;
    }
}
