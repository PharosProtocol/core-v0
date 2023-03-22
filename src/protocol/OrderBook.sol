// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import "lib/tractor/Tractor.sol";
import "src/libraries/LibUtil.sol";

import "src/libraries/LibOrderBook.sol";
import {ITerminal} from "src/interfaces/ITerminal.sol";
import {TerminalCalldata} from "src/libraries/LibTerminal.sol";
import {Utils} from "src/libraries/LibUtil.sol";
// // import {ILiquidator} from "src/modules/LiquidatorFactory.sol";

// NOTE enabling partial fills would benefit from on-chain validation of orders so that each taker does not need
//      to pay gas to independently verify. Verified orders could be signed by Tractor.

/**
 * @notice An Order is a standing offer to take one side of a position within a set of parameters. Orders can
 *  represent both lenders and borrowers. Capital to back an order is held in an Account, though the Account may
 *  not have enough assets.
 *
 *  An Order can be created at no cost by signing a transaction with the signature of the Order. An Operator can
 *  create a compatible Position between two compatible Orders, which will be verified at Position creation.
 */
contract OrderBook is Tractor {
    enum BlueprintDataType {
        OFFER,
        REQUEST,
        POSITION
    }

    string constant PROTOCOL_NAME = "modulus";
    string constant PROTOCOL_VERSION = "1.0.0";

    event OrdersFilled(Agreement position, bytes32 lendOffer, bytes32 borrowOffer, address operator);

    constructor() Tractor(PROTOCOL_NAME, PROTOCOL_VERSION) {}

    function fillOrdersAtMatch(
        OrderMatch calldata orderMatch,
        SignedBlueprint calldata lendBlueprint,
        SignedBlueprint calldata borrowBlueprint
    ) external verifySignature(lendBlueprint) verifySignature(borrowBlueprint) {
        // Orders were both created by the represented user.
        (Offer memory offer, Request memory request) = decodeAndVerifyMetadata(lendBlueprint, borrowBlueprint);

        // Verify that position is compatible with the offer and the request.
        verifyCompatibility(orderMatch, offer, request);

        // Set Position data that cannot be computed off chain by caller.
        Agreement memory position = generateAgreement(orderMatch, offer, request);
        position.deploymentTime = block.timestamp;
        position.addr = ITerminal(position.terminal.addr).createPosition(
            abi.decode(position.terminal.parameters, (TerminalCalldata))
        );
        emit OrdersFilled(position, lendBlueprint.blueprintHash, borrowBlueprint.blueprintHash, msg.sender);

        // Create blueprint to store signed Position off chain via events.
        SignedBlueprint memory signedBlueprint;
        signedBlueprint.blueprint.publisher = address(this);
        signedBlueprint.blueprint.data =
            encodeDataField(bytes1(uint8(BlueprintDataType.POSITION)), abi.encode(position));
        signedBlueprint.blueprint.endTime = type(uint256).max;
        signedBlueprint.blueprintHash = getBlueprintHash(signedBlueprint.blueprint);
        // TODO: Security: Is is possible to intentionally manufacture a blueprint with different data that creates the same hash?
        signBlueprint(signedBlueprint.blueprintHash);
        publishBlueprint(signedBlueprint); // These verifiable blueprints will be used to interact with positions.
    }

    /// @notice decode order blueprint data and ensure blueprint metadata is valid pairing with embedded data.
    function decodeAndVerifyMetadata(SignedBlueprint calldata lendBlueprint, SignedBlueprint calldata borrowBlueprint)
        private
        useBlueprint(lendBlueprint)
        useBlueprint(borrowBlueprint)
        returns (Offer memory offer, Request memory request)
    {
        bytes1 blueprintDataType;
        bytes memory blueprintData;

        (blueprintDataType, blueprintData) = decodeDataField(lendBlueprint.blueprint.data);
        require(
            uint8(blueprintDataType) == uint8(BlueprintDataType.OFFER), "OrderBook: Invalid lend blueprint data type"
        );
        offer = abi.decode(blueprintData, (Offer));

        (blueprintDataType, blueprintData) = decodeDataField(borrowBlueprint.blueprint.data);
        require(
            uint8(blueprintDataType) == uint8(BlueprintDataType.REQUEST),
            "OrderBook: Invalid borrow blueprint data type"
        );
        request = abi.decode(blueprintData, (Request));

        // The blueprints must have been signed by the users represented by the Orders.
        // Parity between signer and publisher fields must be enforced elsewhere.
        require(lendBlueprint.blueprint.publisher == offer.lender);
        require(borrowBlueprint.blueprint.publisher == request.borrower);
    }

    function verifyCompatibility(OrderMatch calldata orderMatch, Offer memory offer, Request memory request)
        public
        pure
    {
        // Verify Lender and Borrower both reference same components.
        _verifyRangedVariables(orderMatch, offer, request);
        _verifyAllowedVariables(orderMatch, offer, request);
    }

    /// @notice Verify that the proposed match is compatible with the ranged variables of offer and request.
    /// @dev this seems very error prone, however without the ability to access struct members via string, it is
    ///      unclear how to do this better.
    function _verifyRangedVariables(OrderMatch calldata orderMatch, Offer memory offer, Request memory request)
        private
        pure
    {
        require(
            Utils.isInRangePair(orderMatch.minCollateralRatio, offer.minCollateralRatio, request.minCollateralRatio)
        );
        require(Utils.isInRangePair(orderMatch.durationLimit, offer.durationLimit, request.durationLimit));
        require(Utils.isInRangePair(orderMatch.loanAmount, offer.loanAmount, request.loanAmount));
        require(Utils.isInRangePair(orderMatch.collateralAmount, offer.collateralAmount, request.collateralAmount));

        require(Utils.isInRangePair(orderMatch.assessor, offer.assessor, request.assessor));
        require(Utils.isInRangePair(orderMatch.rewarder, offer.rewarder, request.rewarder));
        require(Utils.isInRangePair(orderMatch.liquidator, offer.liquidator, request.liquidator));
    }

    /// @notice Verify that the proposed match is compatible with the explicitly allowed variables of offer and request.
    /// @dev this seems very error prone, however without the ability to access struct members via string, it is
    ///      unclear how to do this better.
    function _verifyAllowedVariables(OrderMatch calldata orderMatch, Offer memory offer, Request memory request)
        private
        pure
    {
        // TODO change account from wallet address to account address to enable multiple accounts per user.
        // Takers are allowed.
        if (offer.takers.length > 0) require(offer.takers[orderMatch.takerIdx.offer] == request.borrower);
        if (request.takers.length > 0) require(request.takers[orderMatch.takerIdx.request] == offer.lender);

        require(Utils.isSameAllowedModuleRef(orderMatch.loanOracle, offer.loanOracle, request.loanOracle));
        require(
            Utils.isSameAllowedModuleRef(orderMatch.collateralOracle, offer.collateralOracle, request.collateralOracle)
        );
        require(Utils.isSameAllowedModuleRef(orderMatch.terminal, offer.terminal, request.terminal));
    }

    function generateAgreement(OrderMatch calldata orderMatch, Offer memory offer, Request memory request)
        private
        pure
        returns (Agreement memory position)
    {
        position.minCollateralRatio = orderMatch.minCollateralRatio;
        position.durationLimit = orderMatch.durationLimit;
        position.loanAmount = orderMatch.loanAmount;
        position.collateralAmount = orderMatch.collateralAmount;
        position.assessor = orderMatch.assessor;
        position.rewarder = orderMatch.rewarder;
        position.liquidator = orderMatch.liquidator;

        position.lender = offer.lender;
        position.borrower = request.borrower;
        position.loanOracle = offer.loanOracle[orderMatch.loanOracle.offer];
        position.collateralOracle = offer.collateralOracle[orderMatch.collateralOracle.offer];
        position.terminal = offer.terminal[orderMatch.terminal.offer];
    }
}
