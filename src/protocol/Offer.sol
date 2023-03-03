// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "lib/tractor/Tractor.sol";
import {IComparableParameterFactory, IFactory} from "src/modules/Factory.sol";
import {IAssessor} from "src/modules/AssessorFactory.sol";
// import {ILiquidator} from "src/modules/LiquidatorFactory.sol";

// This struct is used to identify an item shared in both lender and borrower arrays.
struct IndexPair {
    uint128 lender;
    uint128 borrower;
}

struct Offer {
    bool isBorrowRequest;
    address[] allowedCollateralAssets; // bytes32 allowedCollateralAssetSet;
    address[] allowedLendAssets; // bytes32 allowedCollateralAssetSet;
    /* Modules */
    address[] allowedTakers;
    address[] allowedOracles; // bytes32 oracleSet;
    address[] allowedTerminals; // bytes32 terminalSet;
    bytes[] terminalCallData; // used from borrower
    address[2] assessorRange; // Least to most expensive assessor instances of same type willing to use
    address[2] liquidatorRange; // Least to most expensive liquidator instances of same type willing to use
    uint256[2] collateralizationRatioRange; // Min and max collateralization ratio
    uint256[2] durationLimitRange; // Min and max collateralization ratio
}

// Data configured by operator who calls transaction to create position.
struct PositionConfig {
    address lender;
    address borrower;
    IndexPair takerIdx;
    IndexPair terminalIdx; // address (position factory)
    // bytes callData; // Set by operator, not verified by modulus. /// NOTE cannot have here, operator may be hostile.
    bytes32 lendAccount;
    IndexPair lendAssetIdx; // address
    IndexPair lendOracleIdx; // address
    uint256 lendAmount;
    bytes32 borrowAccount;
    IndexPair collateralAssetIdx; // address
    IndexPair collateralOracleIdx; // address
    uint256 collateralizationRatio;
    address assessorFactory;
    address assessor;
    address liquidator;
    uint256 durationLimit;
}

struct PositionRecord {
    uint256 maxCollateralizationRatio;
    uint256 maxCloseTime;
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
contract Basin is Tractor {
    enum BlueprintDataType {OFFER}

    string constant PROTOCOL_NAME = "modulus";
    string constant PROTOCOL_VERSION = "1.0.0";

    event CreatedPosition(address operator, address position, bytes32 lendOffer, bytes32 borrowOffer);

    constructor() Tractor(PROTOCOL_NAME, PROTOCOL_VERSION) {}

    function createPosition(
        PositionConfig calldata position,
        SignedBlueprint calldata lendBlueprint,
        SignedBlueprint calldata borrowBlueprint
    )
        external
        verifySignature(lendBlueprint)
        verifySignature(borrowBlueprint)
        verifyUseBlueprint(lendBlueprint)
        verifyUseBlueprint(borrowBlueprint)
    {
        Offer memory lendOffer;
        Offer memory borrowOffer;
        // Block scoping to avoid stack limit.
        {
            (, bytes calldata lendBlueprintData) = decodeDataField(lendBlueprint.blueprint.data);
            (, bytes calldata borrowBlueprintData) = decodeDataField(borrowBlueprint.blueprint.data);
            lendOffer = abi.decode(lendBlueprintData, (Offer));
            borrowOffer = abi.decode(borrowBlueprintData, (Offer));
        }

        // Verify that position is compatible with both offers.
        verifyCompatibility(position, lendOffer, borrowOffer, lendBlueprint.blueprint, borrowBlueprint.blueprint);

        emit CreatedPosition(
            msg.sender,
            IFactory(borrowOffer.allowedTerminals[position.terminalIdx.borrower]).createClone(
                borrowOffer.terminalCallData[position.terminalIdx.borrower]
            ),
            lendBlueprint.blueprintHash,
            borrowBlueprint.blueprintHash
            );
    }

    function verifyCompatibility(
        PositionConfig calldata position,
        Offer memory lendOffer,
        Offer memory borrowOffer,
        Blueprint calldata lendBlueprint,
        Blueprint calldata borrowBlueprint
    ) public view {
        _verifyLenderAndBorrower(position, lendOffer, borrowOffer, lendBlueprint, borrowBlueprint);
        // Check that position indices on both offers reference same components.
        _verifyMatchedReferences(position, lendOffer, borrowOffer);
        // Check that position is compatible with both offers.
        _verifyCompatible(position, lendOffer);
        _verifyCompatible(position, borrowOffer);
    }

    function _verifyLenderAndBorrower(
        PositionConfig calldata position,
        Offer memory lendOffer,
        Offer memory borrowOffer,
        Blueprint calldata lendBlueprint,
        Blueprint calldata borrowBlueprint
    ) private pure {
        // Check blueprint data. Verify Lender and Borrower.
        require(lendBlueprint.publisher == position.lender);
        require(lendOffer.isBorrowRequest == false);
        require(borrowBlueprint.publisher == position.borrower);
        require(borrowOffer.isBorrowRequest == true);

        // Takers are allowed.
        if (lendOffer.allowedTakers.length > 0) {
            require(lendOffer.allowedTakers[position.takerIdx.lender] == position.borrower);
        }
        if (borrowOffer.allowedTakers.length > 0) {
            require(borrowOffer.allowedTakers[position.takerIdx.borrower] == position.lender);
        }
    }

    // Verify Lender and Borrower both reference same components.
    function _verifyMatchedReferences(
        PositionConfig calldata position,
        Offer memory lendOffer,
        Offer memory borrowOffer
    ) private pure {
        require(
            lendOffer.allowedLendAssets[position.lendAssetIdx.lender]
                == borrowOffer.allowedLendAssets[position.lendAssetIdx.borrower]
        );
        require(
            lendOffer.allowedOracles[position.lendOracleIdx.lender]
                == borrowOffer.allowedOracles[position.lendOracleIdx.borrower]
        );
        require(
            lendOffer.allowedCollateralAssets[position.collateralAssetIdx.lender]
                == borrowOffer.allowedCollateralAssets[position.collateralAssetIdx.borrower]
        );
        require(
            lendOffer.allowedOracles[position.collateralOracleIdx.lender]
                == borrowOffer.allowedOracles[position.collateralOracleIdx.borrower]
        );
        require(
            lendOffer.allowedTerminals[position.terminalIdx.lender]
                == borrowOffer.allowedTerminals[position.terminalIdx.borrower]
        );
    }

    function _verifyCompatible(PositionConfig calldata position, Offer memory offer) private view {
        // Assessor within range.
        IComparableParameterFactory af = IComparableParameterFactory(position.assessorFactory);
        require(!af.isLT(position.assessor, offer.assessorRange[0])); // fails is assessor is not from factory.
        require(!af.isGT(position.assessor, offer.assessorRange[1]));

        // TODO: implement liquidator factory.
        // // Liquidator within range.
        // ILiquidator l = ILiquidator(position.liquidator);
        // require(!l.isLT(offer.liquidatorRange[0]) && !l.isGT(offer.liquidatorRange[1]));

        // Collateralization ratio within range.
        require(
            position.collateralizationRatio >= offer.collateralizationRatioRange[0]
                && position.collateralizationRatio <= offer.collateralizationRatioRange[1]
        );

        // Duration limit within range.
        require(
            position.durationLimit >= offer.durationLimitRange[0]
                && position.durationLimit <= offer.durationLimitRange[1]
        );
    }
}
