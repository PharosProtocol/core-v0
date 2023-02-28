// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "lib/tractor/Tractor.sol";

struct Order {
    address owner;
    bool isBorrowRequest;
    address allowedCollateral; // bytes32 allowedCollateralAssetSet;
    uint256 allowedAmount; // mapping(address => uint256) assets;
    /* Modules */
    bytes32 oracleSet;
    address minAssessor; // Least expensive assessor of this type willing to use
    address maxAssessor; // Most expensive assessor of this type willing to use
    bytes32 terminalSet;
    address minLiquidator; // Least expensive liquidator instance of this type willing to use
    address maxLiquidator; // Most expensive liquidator instance of this type willing to use
    /* Scope */
    uint256 minCollateralizationRatio;
    uint256 maxCollateralizationRatio;
    uint256 minDurationLimit;
    uint256 maxDurationLimit;
    address[] allowedFillers;
    /* logistics */
    uint256 deadline;
}

/**
 * An Offer is a standing offer to take one side of a position within a set of parameters. Offers can represent both
 * lenders and borrowers. Capital to back an offer is held in an Account, though the Account may not have enough assets.
 *
 * An Offer can be created at no cost by signing a transaction with the hash of the Offer. The Offer Filler will then
 * verify the signature and create a mutually valid position.
 *
 * Offers are created without affecting state via signatures. Therefore, an offer that has been confirmed to be
 * authentic via its signature but is not yet stored here is known to still have its full value available.
 */
contract OrderBook is Tractor {
    enum BlueprintDataType {OFFER}

    event CreatedPosition(address operator, bytes32 lendOffer, bytes32 borrowOffer, address position);

    /**
     * @notice Fill lend offer and borrow offer at mutually agreeable terms.
     * @param   lendOffer  .
     * @param   borrowOffer  .
     * @param   position  .
     */
    function createPosition(Blueprint calldata lendOffer, Blueprint calldata borrowOffer, Position calldata position)
        verifySignature(lendOffer)
        verifySignature(borrowOffer)
        checkMetadataIncrementNonce(lendOffer)
        checkMetadataIncrementNonce(borrowOffer)
    {}
}
