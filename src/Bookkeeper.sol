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
        require(uint8(blueprintDataType) == uint8(BlueprintDataType.ORDER), "Blueprint not an Order type");

        // Verify publishers own accounts. May or may not be EOA.
        require(
            msg.sender == IAccount(fill.account.addr).getOwner(fill.account.parameters),
            "fillOrder: Taker != msg.sender"
        );
        Order memory order = abi.decode(blueprintData, (Order));
        require(
            orderBlueprint.blueprint.publisher == IAccount(order.account.addr).getOwner(order.account.parameters),
            "Publisher does not own lender account "
        );
        if (order.fillers.length > 0) {
            require(order.fillers[fill.takerIdx] == msg.sender, "Bookkeeper: Invalid taker");
        }

        LibBookkeeper.verifyFill(fill, order);
        Agreement memory agreement = LibBookkeeper.agreementFromOrder(fill, order);

        uint256 loanValue = (agreement.loanAmount*IOracle(agreement.loanOracle.addr).getOpenPrice(agreement.loanOracle.parameters, agreement.fillerData)) / C.RATIO_FACTOR;
        uint256 collValue = (agreement.collAmount*IOracle(agreement.collOracle.addr).getOpenPrice(agreement.collOracle.parameters, agreement.fillerData)) / C.RATIO_FACTOR; 
        uint256 initCollateralRatio;
        if(order.isLeverage) {
         initCollateralRatio = (loanValue + collValue)*C.RATIO_FACTOR/loanValue;
        } else{
         initCollateralRatio= collValue*C.RATIO_FACTOR/loanValue;
        }
        require(initCollateralRatio >= agreement.minCollateralRatio , "not enough collateral");

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
            agreement.lenderAccount.parameters,
            agreement.fillerData
        );
        IAccount(agreement.borrowerAccount.addr).unloadToPosition(
            agreement.position.addr,
            agreement.collAsset,
            agreement.collAmount,
            agreement.borrowerAccount.parameters,
            agreement.fillerData
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

        uint256 closeAmount = position.getCloseAmount(agreement); // only used for event, consider removing
        uint256 assessorCost = IAssessor(agreement.assessor.addr).getCost(agreement);
        uint256 loanOraclePrice = IOracle(agreement.loanOracle.addr).getClosePrice(agreement.loanOracle.parameters, agreement.fillerData);
        uint256 lenderBalanceBefore = lenderAccount.getBalance(agreement.loanAsset, agreement.lenderAccount.parameters);
        uint256 amountToLender = agreement.loanAmount + ((assessorCost * C.RATIO_FACTOR) / loanOraclePrice);
        
        // Close the position
        position.close( agreement, amountToLender);

        uint256 lenderBalanceAfter = lenderAccount.getBalance(agreement.loanAsset, agreement.lenderAccount.parameters);
        require((lenderBalanceAfter - lenderBalanceBefore) >= amountToLender, "Not enough to close the loan");

        // Mark the position as closed from the Bookkeeper's point of view.
        agreementClosed[keccak256(abi.encodePacked(agreement.position.addr))] = true;

        emit PositionClosed( agreementBlueprint, agreement.position.addr, msg.sender, closeAmount,loanOraclePrice, assessorCost);
        position.transferContract(msg.sender);
    }


    //Unwind position

        function unwindPosition(
        SignedBlueprint calldata agreementBlueprint
    ) external nonReentrant verifySignature(agreementBlueprint) {
        (bytes1 blueprintDataType, bytes memory blueprintData) = unpackDataField(agreementBlueprint.blueprint.data);
        require(blueprintDataType == bytes1(uint8(BlueprintDataType.AGREEMENT)), "unwindPosition: invalid data type");
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));

        bool isBorrower = msg.sender ==
        IAccount(agreement.borrowerAccount.addr).getOwner(agreement.borrowerAccount.parameters);
        require(isBorrower, "error: caller is not the borrower");

        IPosition(agreement.position.addr).unwind(agreement);

    }

    // Liquidate


    // update so that it takes liquidatorlogic as an argument and then it first transfers ownership, calls the liquidator logic then does the checks
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
        uint256 loanOraclePrice = IOracle(agreement.loanOracle.addr).getClosePrice(agreement.loanOracle.parameters, agreement.fillerData);
        uint256 collOraclePrice = IOracle(agreement.collOracle.addr).getClosePrice(agreement.collOracle.parameters, agreement.fillerData);
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

        emit PositionClosed(agreementBlueprint, agreement.position.addr, msg.sender, closeAmount, loanOraclePrice, assessorCost);
        //Transfer Position to caller
        position.transferContract(msg.sender);
    }
}
