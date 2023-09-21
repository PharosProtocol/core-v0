// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Blueprint, SignedBlueprint, Tractor} from "@tractor/Tractor.sol";

import {IOracle} from "src/interfaces/IOracle.sol";
import {IAccount} from "src/interfaces/IAccount.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {ILiquidator} from "src/interfaces/ILiquidator.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {C} from "src/libraries/C.sol";
import {Order, Fill, Agreement, LibBookkeeper} from "src/libraries/LibBookkeeper.sol";
import {LibUtils} from "src/libraries/LibUtils.sol";

contract Bookkeeper is Tractor, ReentrancyGuard {
    enum BlueprintDataType {
        NULL,
        ORDER,
        AGREEMENT
    }

    string public constant PROTOCOL_NAME = "pharos";
    string public constant PROTOCOL_VERSION = "0.1.0";

    mapping(bytes32 => bool) public agreementClosed;
    mapping(bytes32 => bool) public liquidationLock;



    event OrderFilled(SignedBlueprint agreement, bytes32 orderBlueprintHash, address taker);
    event PositionClosed(SignedBlueprint agreement, address position, address closer, uint256 closeValue, uint256 loanOrcale,uint256 assesorCost );
    event PositionLiquidated(SignedBlueprint agreement, address position, address liquidator);

    constructor() Tractor(PROTOCOL_NAME, PROTOCOL_VERSION) {}

    // Fill Order
    function fillOrder(
        Fill calldata fill,
        SignedBlueprint calldata orderBlueprint
    ) external nonReentrant verifySignature(orderBlueprint) {
        // decode order blueprint data and ensure blueprint metadata is valid pairing with embedded data
        (bytes1 blueprintDataType, bytes memory blueprintData) = unpackDataField(orderBlueprint.blueprint.data);
        require(uint8(blueprintDataType) == uint8(BlueprintDataType.ORDER), "BKDTMM");

        // Verify publishers own accounts. May or may not be EOA.
        require(
            msg.sender == IAccount(fill.account.addr).getOwner(fill.account.parameters),
            "fillOrder: Taker != msg.sender"
        );
        Order memory order = abi.decode(blueprintData, (Order));
        require(
            orderBlueprint.blueprint.publisher == IAccount(order.account.addr).getOwner(order.account.parameters),
            "BKPOMM"
        );
        if (order.fillers.length > 0) {
            require(order.fillers[fill.takerIdx] == msg.sender, "Bookkeeper: Invalid taker");
        }

        LibBookkeeper.verifyFill(fill, order);
        Agreement memory agreement = LibBookkeeper.agreementFromOrder(fill, order);

        uint256 loanValue = agreement.loanAmount *
            IOracle(agreement.loanOracle.addr).getOpenPrice(agreement.loanOracle.parameters)/C.RATIO_FACTOR;
        uint256 collateralValue;

        if (agreement.isLeverage) {
            uint256 initCollateralRatio = order.isOffer
                ? fill.borrowerConfig.initCollateralRatio
                : order.borrowerConfig.initCollateralRatio;

            if (order.isOffer) {
                agreement.lenderAccount = order.account;
                agreement.borrowerAccount = fill.account;
            } else {
                agreement.lenderAccount = fill.account;
                agreement.borrowerAccount = order.account;
            }

            collateralValue = (loanValue * (initCollateralRatio - 1e18)) / C.RATIO_FACTOR;
        } else {
            uint256 initCollateralRatio = order.isOffer
                ? fill.borrowerConfig.initCollateralRatio
                : order.borrowerConfig.initCollateralRatio;

            if (order.isOffer) {
                agreement.lenderAccount = order.account;
                agreement.borrowerAccount = fill.account;
            } else {
                agreement.lenderAccount = fill.account;
                agreement.borrowerAccount = order.account;
            }

            collateralValue = (loanValue * initCollateralRatio) / C.RATIO_FACTOR;
        }

        agreement.position.parameters = order.isOffer
            ? fill.borrowerConfig.positionParameters
            : order.borrowerConfig.positionParameters;
        agreement.collAmount =
            collateralValue *C.RATIO_FACTOR/
            IOracle(agreement.collOracle.addr).getOpenPrice(agreement.collOracle.parameters);
        
        
        // Set Position data that cannot be computed off chain by caller.
        agreement.deploymentTime = block.timestamp;

        _openPosition(agreement);

        SignedBlueprint memory signedBlueprint = _signAgreement(agreement);
        emit OrderFilled(signedBlueprint, orderBlueprint.blueprintHash, msg.sender);
    }

    // Sign Agreement

    function _signAgreement(Agreement memory agreement) private returns (SignedBlueprint memory signedBlueprint) {
        // Create blueprint to store signed Agreement off chain via events.
        signedBlueprint.blueprint.publisher = address(this);
        signedBlueprint.blueprint.data = packDataField(
            bytes1(uint8(BlueprintDataType.AGREEMENT)),
            abi.encode(agreement)
        );
        signedBlueprint.blueprint.endTime = type(uint256).max;
        signedBlueprint.blueprintHash = getBlueprintHash(signedBlueprint.blueprint);
        // SECURITY Is is possible to intentionally manufacture a blueprint with different data that creates the same hash?
        signBlueprint(signedBlueprint.blueprintHash);
        // publishBlueprint(signedBlueprint); // These verifiable blueprints will be used to interact with positions.
    }

    // Open Position
    function _openPosition(Agreement memory agreement) private {
        (bool success, bytes memory data) = agreement.factory.call(abi.encodeWithSignature("createClone()"));
        require(success, "factory error: create clone failed");

        agreement.position.addr = abi.decode(data, (address));

        IAccount(agreement.lenderAccount.addr).unloadToPosition(
            agreement.position.addr,
            agreement.loanAsset,
            agreement.loanAmount,
            agreement.lenderAccount.parameters
        );
        IAccount(agreement.borrowerAccount.addr).unloadToPosition(
            agreement.position.addr,
            agreement.collAsset,
            agreement.collAmount,
            agreement.borrowerAccount.parameters
        );

        IPosition(agreement.position.addr).open(agreement);

        require(!LibBookkeeper.isLiquidatable(agreement), "unhealthy deployment");
    }

    // Close Position

    function closePosition(
        SignedBlueprint calldata agreementBlueprint
    ) external nonReentrant verifySignature(agreementBlueprint) {
        (bytes1 blueprintDataType, bytes memory blueprintData) = unpackDataField(agreementBlueprint.blueprint.data);
        require(blueprintDataType == bytes1(uint8(BlueprintDataType.AGREEMENT)), "closePosition: Invalid data type");
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));

        bool isBorrower = msg.sender ==
            IAccount(agreement.borrowerAccount.addr).getOwner(agreement.borrowerAccount.parameters);
        bool isLiquidatable = LibBookkeeper.isLiquidatable(agreement);
        // Require either the sender to be the borrower or the agreement to be liquidatable
        require(
            isBorrower || isLiquidatable,
            "error: Sender is neither the borrower nor the agreement is liquidatable"
        );

        uint256 closeAmount = IPosition(agreement.position.addr).getCloseValue(agreement);
        uint256 assesorCost = IAssessor(agreement.assessor.addr).getCost(agreement);
        uint256 loanOralcePrice = IOracle(agreement.loanOracle.addr).getClosePrice(
                agreement.loanOracle.parameters);
        
        uint256 lenderOriginalBalance = IAccount(agreement.lenderAccount.addr).getBalance(
            agreement.loanAsset,
            agreement.lenderAccount.parameters
        );

        IPosition(agreement.position.addr).close(msg.sender,agreement);

        uint256 lenderNewBalance = IAccount(agreement.lenderAccount.addr).getBalance(
            agreement.loanAsset,
            agreement.lenderAccount.parameters
        );

        require(
            lenderNewBalance - lenderOriginalBalance >= agreement.loanAmount + assesorCost,
            "Not enough to close the loan"
        );

        // Marks position as closed from Bookkeeper pov.
        agreementClosed[keccak256(abi.encodePacked(agreement.position.addr))] = true;
        emit PositionClosed(agreementBlueprint, agreement.position.addr, msg.sender,closeAmount,loanOralcePrice,assesorCost);

    }

    // Liquidate

    function triggerLiquidation(
        SignedBlueprint calldata agreementBlueprint
    ) external nonReentrant verifySignature(agreementBlueprint) {
        (, bytes memory blueprintData) = unpackDataField(agreementBlueprint.blueprint.data);
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));
        bytes32 agreementId = keccak256(abi.encode(agreement));

        // Check if the loan is already closed
        require(!agreementClosed[agreementId], "Loan already closed.");

        // Ensure this agreement isn't already undergoing liquidation
        require(!liquidationLock[agreementId], "Liquidation already in progress for this agreement.");

        require(LibBookkeeper.isLiquidatable(agreement), "Loan is not eligible for liquidation");

        // Set the lock
        liquidationLock[agreementId] = true;

        // Execute the liquidation
        ILiquidator(agreement.liquidator.addr).liquidate(msg.sender, agreement);

        // If the loan has been closed during the liquidation, no need to recheck its status.
        if (!agreementClosed[agreementId]) {
            // Recheck the liquidation condition post-liquidation
            require(!LibBookkeeper.isLiquidatable(agreement), "Post-liquidation check failed");
        }

        // Release the lock
        liquidationLock[agreementId] = false;
        emit PositionLiquidated(agreementBlueprint, agreement.position.addr, msg.sender);

    }
}
