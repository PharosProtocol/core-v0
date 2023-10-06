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
    string public constant PROTOCOL_VERSION = "0.2.0";

    mapping(bytes32 => bool) public agreementClosed;
    mapping(bytes32 => bool) public liquidationLock;

    event OrderFilled(SignedBlueprint agreement, bytes32 orderBlueprintHash, address taker);
    event PositionClosed(
        SignedBlueprint agreement,
        address position,
        address closer,
        uint256 closeValue,
        uint256 loanOrcale,
        uint256 assessorCost
    );
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

        uint256 loanValue = (agreement.loanAmount *
            IOracle(agreement.loanOracle.addr).getOpenPrice(agreement.loanOracle.parameters)) / C.RATIO_FACTOR;
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
            (collateralValue * C.RATIO_FACTOR) /
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
        require(isBorrower, "error: Caller is not the borrower");

        IPosition position = IPosition(agreement.position.addr);
        IAccount lenderAccount = IAccount(agreement.lenderAccount.addr);
        uint256 closeAmount = position.getCloseAmount(agreement);
        uint256 assessorCost = IAssessor(agreement.assessor.addr).getCost(agreement);
        uint256 loanOraclePrice = IOracle(agreement.loanOracle.addr).getClosePrice(agreement.loanOracle.parameters);
        uint256 lenderBalanceBefore = lenderAccount.getBalance(agreement.loanAsset, agreement.lenderAccount.parameters);
        uint256 amountToLender = agreement.loanAmount + ((assessorCost * C.RATIO_FACTOR) / loanOraclePrice);
        
        // Close the position
        position.close( agreement, amountToLender);

        uint256 lenderBalanceAfter = lenderAccount.getBalance(agreement.loanAsset, agreement.lenderAccount.parameters);
        require((lenderBalanceAfter - lenderBalanceBefore) >= amountToLender, "Not enough to close the loan");

        // Mark the position as closed from the Bookkeeper's point of view.
        agreementClosed[keccak256(abi.encodePacked(agreement.position.addr))] = true;

        emit PositionClosed(
            agreementBlueprint,
            agreement.position.addr,
            msg.sender,
            closeAmount,
            loanOraclePrice,
            assessorCost
        );
        position.transferContract(msg.sender);
    }


    //Unwind position

        function unwindPosition(
        SignedBlueprint calldata agreementBlueprint
    ) external nonReentrant verifySignature(agreementBlueprint) {
        (bytes1 blueprintDataType, bytes memory blueprintData) = unpackDataField(agreementBlueprint.blueprint.data);
        require(blueprintDataType == bytes1(uint8(BlueprintDataType.AGREEMENT)), "closePosition: Invalid data type");
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));

        bool isBorrower = msg.sender ==
        IAccount(agreement.borrowerAccount.addr).getOwner(agreement.borrowerAccount.parameters);
        require(isBorrower, "error: Caller is not the borrower");

        IPosition position = IPosition(agreement.position.addr);

        position.unwind(agreement);
    }

    // Liquidate

    function triggerLiquidation(
        SignedBlueprint calldata agreementBlueprint
    ) external nonReentrant verifySignature(agreementBlueprint) {
        (, bytes memory blueprintData) = unpackDataField(agreementBlueprint.blueprint.data);
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));
        bytes32 agreementId = keccak256(abi.encode(agreement));
        IPosition position = IPosition(agreement.position.addr);

        // Check if the loan is already closed
        require(!agreementClosed[agreementId], "Loan already closed.");

        require(LibBookkeeper.isLiquidatable(agreement), "Loan is not eligible for liquidation");

        // Get reward and amounts to distribute
        uint256 assessorCost = IAssessor(agreement.assessor.addr).getCost(agreement);
        uint256 loanOraclePrice = IOracle(agreement.loanOracle.addr).getClosePrice(agreement.loanOracle.parameters);
        uint256 collOraclePrice = IOracle(agreement.collOracle.addr).getClosePrice(agreement.collOracle.parameters);
        uint256 amountToLender = agreement.loanAmount + ((assessorCost * C.RATIO_FACTOR) / loanOraclePrice);
        uint256 closeAmount = position.getCloseAmount(agreement);
        uint256 amountToLiquidator = ILiquidator(agreement.liquidator.addr).getReward(agreement);
        uint256 amountToBorrower= ((closeAmount - amountToLender - amountToLiquidator)*C.RATIO_FACTOR)/collOraclePrice ;

        // Transfer assets to lender and borrower from liquidator
        IAccount(agreement.lenderAccount.addr).loadFromLiquidator(
                        msg.sender,
                        agreement.loanAsset,
                        amountToLender,
                        agreement.lenderAccount.parameters
                    );

        IAccount(agreement.borrowerAccount.addr).loadFromLiquidator(
                    msg.sender,
                    agreement.collAsset,
                    amountToBorrower,
                    agreement.borrowerAccount.parameters
                );


        emit PositionLiquidated(agreementBlueprint, agreement.position.addr, msg.sender);

        // Mark the position as closed from the Bookkeeper's point of view.
        agreementClosed[keccak256(abi.encodePacked(agreement.position.addr))] = true;

        emit PositionClosed(
            agreementBlueprint,
            agreement.position.addr,
            msg.sender,
            closeAmount,
            loanOraclePrice,
            assessorCost
        );
        //Transfer Position to caller
        position.transferContract(msg.sender);
    }
}
