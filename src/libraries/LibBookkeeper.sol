// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IPosition} from "src/interfaces/IPosition.sol";
import {IAccount} from "src/interfaces/IAccount.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {ILiquidator} from "src/interfaces/ILiquidator.sol";
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
    uint256[] minCollateralRatio;
    address[] fillers;
    bool isLeverage;
    uint256 maxDuration;
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
    uint256 collAmount; // Borrower chooses starting health by setting amount of collateral.
    bytes positionParameters; //Borrower parameters if needed by position
}

/// @notice Taker defined Position configuration that is compatible with an offer or a request.
struct Fill {
    PluginReference account;
    uint256 loanAmount; // should be valid with both minFillRatios and account balances
    uint256 takerIdx; // ignored if no taker allowlist.
    uint256 loanAssetIdx; // need to verify with the oracle
    uint256 collAssetIdx; // need to verify with the oracle
    uint256 factoryIdx;
    bytes fillerData; // If filler needs to input any data like tokenId for ERC-1155
    // Sided config
    bool isOfferFill;
    BorrowerConfig borrowerConfig; // Only set when filling Offers
}

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
    bool isLeverage;
    PluginReference lenderAccount;
    PluginReference borrowerAccount;
    PluginReference assessor;
    PluginReference liquidator;
    PluginReference loanOracle;
    PluginReference collOracle;
    address factory;
    PluginReference position; // addr set by bookkeeper.
    uint256 deploymentTime; // set by bookkeeper
    bytes fillerData;
}

struct LiquidationData {
        uint256 loanOraclePrice;
        uint256 collOraclePrice;
        uint256 amountToLender;
        uint256 amountToLiquidator;
        uint256 amountToBorrower;
        uint256 lenderBalanceBefore;
        uint256 borrowerBalanceBefore;
    }

library LibBookkeeper {
    /// @notice verify that a fill is valid for an order.
    /// @dev Reverts with reason if not valid.
    function verifyFill(Fill calldata fill, Order memory order) internal pure {
        if (!order.isOffer) {
            require(!fill.isOfferFill, "offer fill of offer");
        } else {
            require(fill.isOfferFill, "request fill of request");
        }

        require(fill.loanAmount >= order.minLoanAmounts[fill.loanAssetIdx], "loanAmount too small");

    }

    /// @dev assumes compatibility between match, offer, and request already verified.
    /// @dev does not fill position address, as it is not known until deployment.
    function agreementFromOrder(
        Fill calldata fill,
        Order memory order
    ) internal pure returns (Agreement memory agreement) {
        agreement.maxDuration = order.maxDuration;
        agreement.assessor = order.assessor;
        agreement.liquidator = order.liquidator;
        agreement.loanAsset = order.loanAssets[fill.loanAssetIdx];
        agreement.loanOracle = order.loanOracles[fill.loanAssetIdx];
        agreement.collAsset = order.collAssets[fill.collAssetIdx];
        agreement.collOracle = order.collOracles[fill.collAssetIdx];
        agreement.minCollateralRatio = order.minCollateralRatio[fill.collAssetIdx];
        agreement.factory = order.factories[fill.factoryIdx];
        agreement.loanAmount = fill.loanAmount;
        agreement.collAmount=fill.borrowerConfig.collAmount;
        agreement.fillerData= fill.fillerData;
        if (order.isOffer) {
        agreement.lenderAccount = order.account;
        agreement.borrowerAccount = fill.account;
        agreement.position.parameters = fill.borrowerConfig.positionParameters;
    } else {
        agreement.lenderAccount = fill.account;
        agreement.borrowerAccount = order.account;
        agreement.position.parameters = order.borrowerConfig.positionParameters;
        }
        

    }

/// @dev Liquidation based on expiration or CR 
    function isLiquidatable(Agreement memory agreement) internal returns (bool) {
        IPosition position = IPosition(agreement.position.addr);

        // If past expiration, liquidatable.
        if (block.timestamp > agreement.deploymentTime + agreement.maxDuration) {
            return true;
        }

        // Calculate closeAmount and assessorCost
        uint256 closeAmount = position.getCloseAmount(agreement);
        uint256 assessorCost = IAssessor(agreement.assessor.addr).getCost(agreement);

        // Check for liquidation based on collateral ratio
        uint256 loanOraclePrice = IOracle(agreement.loanOracle.addr).getClosePrice(agreement.loanOracle.parameters, agreement.fillerData);
        uint256 openLoanValue = agreement.loanAmount * loanOraclePrice / C.RATIO_FACTOR  + assessorCost;

        uint256 collateralRatio = closeAmount *C.RATIO_FACTOR / openLoanValue;

            if (collateralRatio < (agreement.minCollateralRatio)) {
            return true;
            }
            return false;

        }

    function executeLiquidation(
        Agreement memory agreement,
        IPosition position,
        IAccount lenderAccount,
        IAccount borrowerAccount,
        bytes calldata liquidatorLogic

    )
        internal
    {
        LiquidationData memory ld;
        ld.loanOraclePrice = IOracle(agreement.loanOracle.addr).getClosePrice(agreement.loanOracle.parameters, agreement.fillerData);
        ld.collOraclePrice = IOracle(agreement.collOracle.addr).getClosePrice(agreement.collOracle.parameters, agreement.fillerData);
        ld.amountToLender = agreement.loanAmount + ((IAssessor(agreement.assessor.addr).getCost(agreement) * C.RATIO_FACTOR) / ld.loanOraclePrice);
        ld.amountToLiquidator = ILiquidator(agreement.liquidator.addr).getReward(agreement);
        ld.amountToBorrower= ((position.getCloseAmount(agreement) - ld.amountToLender - ld.amountToLiquidator) * C.RATIO_FACTOR) / ld.collOraclePrice;
        ld.lenderBalanceBefore = lenderAccount.getBalance(agreement.loanAsset, agreement.lenderAccount.parameters,agreement.fillerData );
        ld.borrowerBalanceBefore = borrowerAccount.getBalance(agreement.collAsset, agreement.borrowerAccount.parameters,agreement.fillerData );

        // Execute liquidator logic
        position.passThrough(liquidatorLogic);

        uint256 lenderBalanceAfter = lenderAccount.getBalance(agreement.loanAsset, agreement.lenderAccount.parameters, agreement.fillerData);
        uint256 borrowerBalanceAfter = borrowerAccount.getBalance(agreement.collAsset, agreement.borrowerAccount.parameters, agreement.fillerData);
        require((lenderBalanceAfter - ld.lenderBalanceBefore) >= ld.amountToLender, "Lender not paid enough to close loan");
        require((borrowerBalanceAfter - ld.borrowerBalanceBefore) >= ld.amountToBorrower, "Borrower not paid enough to close loan");
    }

}