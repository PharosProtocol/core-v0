// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import "src/libraries/Util.sol";

/**
 * @notice Order representing a Lender.
 */
struct Offer {
    address lender;
    address[] takers;
    /* Ranged variables */
    uint256[2] minCollateralizationRatioRange;
    uint256[2] durationLimitRange;
    uint256[2] loanAmountRange;
    uint256[2] collateralAmountRange;
    ModuleReference[2] assessorRange;
    ModuleReference[2] rewarderRange;
    ModuleReference[2] liquidatorRange;
    /* Allowlisted variables */
    ModuleReference takerIdx;
    ModuleReference loanAsset;
    ModuleReference loanOracle;
    ModuleReference collateralAsset;
    ModuleReference collateralOracle;
    address[] terminal;
}

/**
 * @notice Order representing a Borrower.
 */
struct Request {
    address borrower;
    address[] takers;
    /* Ranged variables */
    uint256[2] minCollateralizationRatioRange;
    uint256[2] durationLimitRange;
    uint256[2] loanAmountRange;
    uint256[2] collateralAmountRange;
    ModuleReference[2] assessorRange;
    ModuleReference[2] rewarderRange;
    ModuleReference[2] liquidatorRange;
    /* Allowlisted variables */
    ModuleReference takerIdx;
    ModuleReference loanAsset;
    ModuleReference loanOracle;
    ModuleReference collateralAsset;
    ModuleReference collateralOracle;
    ModuleReference terminal;
}

/**
 * @notice Operator defined Position configuration that is compatible with an offer and a request.
 */
struct OrderMatch {
    address lender;
    address borrower;
    /* Ranged variables */
    uint256 minCollateralizationRatio;
    uint256 durationLimit;
    uint256 loanAmount;
    uint256 collateralAmount;
    IndexPair assessor;
    IndexPair rewarder;
    IndexPair liquidator;
    /* Allowlisted variables */
    IndexPair takerIdx;
    IndexPair loanAsset;
    IndexPair loanOracle;
    IndexPair collateralAsset;
    IndexPair collateralOracle;
    IndexPair terminal;
}

/**
 * @notice Position definition is derived from a Match and both Orders.
 * @dev Signed data structure used to store position configuration off chain, reported via events.
 */
struct PositionTerms {
    /* Position variables */
    address lender;
    address borrower;
    uint256 minCollateralizationRatio;
    uint256 durationLimit;
    address loanAsset;
    address collateralAsset;
    uint256 loanAmount;
    uint256 collateralAmount;
    /* Position modules */
    ModuleReference lendOracle;
    ModuleReference collateralOracle;
    ModuleReference terminal;
    ModuleReference assessor;
    ModuleReference rewarder;
    ModuleReference liquidator;
    /* Position deployment details. */
    address addr;
    uint256 deploymentTime;
}

library OrderBookUtils {
    /// @notice verify that the match is compatible with both Orders and create Position terms.
    function DefinePosition(OrderMatch calldata orderMatch, Offer memory offer, Request memory request)
        external
        pure
        returns (PositionTerms memory position)
    {}
}
