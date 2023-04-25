// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "lib/tractor/Tractor.sol";
import "src/LibUtil.sol";

import {Offer, Request, OrderMatch, Agreement, LibBookkeeper} from "src/bookkeeper/LibBookkeeper.sol";
import "src/C.sol";
import "src/modules/oracle/IOracle.sol";
import {IAccount} from "src/modules/account/IAccount.sol";
import {IPosition} from "src/terminal/IPosition.sol";
import {ITerminal} from "src/terminal/ITerminal.sol";
import {ILiquidator} from "src/modules/liquidator/ILiquidator.sol";

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
contract Bookkeeper is Tractor {
    enum BlueprintDataType {
        OFFER,
        REQUEST,
        AGREEMENT
    }

    string constant PROTOCOL_NAME = "modulus";
    string constant PROTOCOL_VERSION = "1.0.0";

    event OrdersFilled(Agreement agreement, bytes32 lendOffer, bytes32 borrowOffer, address operator);
    event LiquidationKicked(address liquidator, address position);

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
        Agreement memory agreement = generateAgreement(orderMatch, offer, request);
        agreement.deploymentTime = block.timestamp;
        agreement.positionAddr = ITerminal(agreement.terminal.addr).createPosition(
            agreement.loanAsset, agreement.loanAmount, agreement.terminal.parameters
        );
        emit OrdersFilled(agreement, lendBlueprint.blueprintHash, borrowBlueprint.blueprintHash, msg.sender);

        // Create blueprint to store signed Position off chain via events.
        SignedBlueprint memory signedBlueprint;
        signedBlueprint.blueprint.publisher = address(this);
        signedBlueprint.blueprint.data =
            encodeDataField(bytes1(uint8(BlueprintDataType.AGREEMENT)), abi.encode(agreement));
        signedBlueprint.blueprint.endTime = type(uint256).max;
        signedBlueprint.blueprintHash = getBlueprintHash(signedBlueprint.blueprint);
        // NOTE: Security: Is is possible to intentionally manufacture a blueprint with different data that creates the same hash?
        signBlueprint(signedBlueprint.blueprintHash);
        publishBlueprint(signedBlueprint); // These verifiable blueprints will be used to interact with positions.
    }

    function kick(SignedBlueprint calldata agreementBlueprint) external verifySignature(agreementBlueprint) {
        (bytes1 blueprintDataType, bytes memory blueprintData) = decodeDataField(agreementBlueprint.blueprint.data);
        require(
            blueprintDataType == bytes1(uint8(BlueprintDataType.AGREEMENT)), "Bookkeeper: Invalid blueprint data type"
        );
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));
        IPosition position = IPosition(agreement.positionAddr);

        // Cannot liquidate if not owned by protocol (liquidating/liquidated/exited).
        require(position.hasRole(C.CONTROLLER_ROLE, address(this)), "Position not owned by protocol");

        require(LibBookkeeper.isLiquidatable(agreement), "Bookkeeper: Position is not liquidatable");
        // Transfer ownership of the position to the liquidator, which includes collateral.
        position.transferContract(agreement.liquidator.addr);
        // Kick the position to begin liquidation.
        // ILiquidator(agreement.liquidator.addr).takeKick(agreementBlueprint.blueprintHash);
        emit LiquidationKicked(agreement.liquidator.addr, agreement.positionAddr);
    }

    // NOTE This puts the assets back into circulating via accounts. Should implement and option to send assets to
    //      a static account.
    function exitPosition(SignedBlueprint calldata agreementBlueprint) external verifySignature(agreementBlueprint) {
        (bytes1 blueprintDataType, bytes memory blueprintData) = decodeDataField(agreementBlueprint.blueprint.data);
        require(
            blueprintDataType == bytes1(uint8(BlueprintDataType.AGREEMENT)), "Bookkeeper: Invalid blueprint data type"
        );
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));
        require(
            msg.sender == IAccount(agreement.borrowerAccount.addr).getOwner(agreement.borrowerAccount.parameters),
            "Bookkeeper: Only borrower can exit position without liquidation"
        );

        uint256 unpaidAmount = IPosition(agreement.positionAddr).exit(agreement, agreement.terminal.parameters);

        // Borrower must pay difference directly if there is not enough value to pay Lender.
        if (unpaidAmount > 0) {
            IAccount(payable(agreement.lenderAccount.addr)).addAssetFrom{
                value: Utils.isEth(agreement.loanAsset) ? unpaidAmount : 0
            }(msg.sender, agreement.loanAsset, unpaidAmount, agreement.lenderAccount.parameters);
        }
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
            uint8(blueprintDataType) == uint8(BlueprintDataType.OFFER), "Bookkeeper: Invalid lend blueprint data type"
        );
        offer = abi.decode(blueprintData, (Offer));

        (blueprintDataType, blueprintData) = decodeDataField(borrowBlueprint.blueprint.data);
        require(
            uint8(blueprintDataType) == uint8(BlueprintDataType.REQUEST),
            "Bookkeeper: Invalid borrow blueprint data type"
        );
        request = abi.decode(blueprintData, (Request));

        // The blueprints must have been signed by the users represented by the Orders.
        // Parity between signer and publisher fields must be enforced elsewhere.
        require(
            lendBlueprint.blueprint.publisher
                == IAccount(offer.lenderAccount.addr).getOwner(offer.lenderAccount.parameters)
        );
        require(
            borrowBlueprint.blueprint.publisher
                == IAccount(request.borrowerAccount.addr).getOwner(request.borrowerAccount.parameters)
        );
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
        require(Utils.isInRangePair(orderMatch.liquidator, offer.liquidator, request.liquidator));
    }

    /// @notice Verify that the proposed match is compatible with the explicitly allowed variables of offer and request.
    /// @dev this seems very error prone, however without the ability to access struct members via string, it is
    ///      unclear how to do this better.
    function _verifyAllowedVariables(OrderMatch calldata orderMatch, Offer memory offer, Request memory request)
        private
        pure
    {
        if (offer.takers.length > 0) {
            require(
                offer.takers[orderMatch.takerIdx.offer]
                    == IAccount(request.borrowerAccount.addr).getOwner(request.borrowerAccount.parameters)
            );
        }
        if (request.takers.length > 0) {
            require(
                request.takers[orderMatch.takerIdx.request]
                    == IAccount(offer.lenderAccount.addr).getOwner(offer.lenderAccount.parameters)
            );
        }

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
        position.liquidator = orderMatch.liquidator;

        position.lenderAccount = offer.lenderAccount;
        position.borrowerAccount = request.borrowerAccount;
        position.loanOracle = offer.loanOracle[orderMatch.loanOracle.offer];
        position.collateralOracle = offer.collateralOracle[orderMatch.collateralOracle.offer];
        position.terminal = offer.terminal[orderMatch.terminal.offer];
    }
}
