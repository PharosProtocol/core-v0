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

    // AUDIT: reading/writing uint256 more efficient than bool?
    // Map indicating if a position has already been kicked.
    mapping(bytes32 => uint256) kicked; // blueprintHash => 0/1 bool

    event OrderFilled(SignedBlueprint agreement, bytes32 orderBlueprintHash, address taker);
    event LiquidationKicked(address liquidator, address position);

    constructor() Tractor(PROTOCOL_NAME, PROTOCOL_VERSION) {}

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

        uint256 loanValue = IOracle(agreement.loanOracle.addr).getOpenPrice(
            agreement.loanOracle.parameters
        );
        uint256 collateralValue;

        if (order.isOffer) {
            agreement.lenderAccount = order.account;
            agreement.borrowerAccount = fill.account;
            collateralValue = (loanValue * fill.borrowerConfig.initCollateralRatio) / C.RATIO_FACTOR;
            agreement.position.parameters = fill.borrowerConfig.positionParameters;
        } else {
            agreement.lenderAccount = fill.account;
            agreement.borrowerAccount = order.account;
            collateralValue = (loanValue * order.borrowerConfig.initCollateralRatio) / C.RATIO_FACTOR;
            agreement.position.parameters = order.borrowerConfig.positionParameters;
        }
        agreement.collAmount = IOracle(agreement.collOracle.addr).getOpenPrice(
            agreement.collOracle.parameters
        );
        // Set Position data that cannot be computed off chain by caller.
        agreement.deploymentTime = block.timestamp;

        _createFundEnterPosition(agreement);

        SignedBlueprint memory signedBlueprint = _signAgreement(agreement);
        emit OrderFilled(signedBlueprint, orderBlueprint.blueprintHash, msg.sender);
    }

    // NOTE CEI?
    function exitPosition(
        SignedBlueprint calldata agreementBlueprint
    ) external payable nonReentrant verifySignature(agreementBlueprint) {
        (bytes1 blueprintDataType, bytes memory blueprintData) = unpackDataField(agreementBlueprint.blueprint.data);
        require(blueprintDataType == bytes1(uint8(BlueprintDataType.AGREEMENT)), "exitPosition: Invalid data type");
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));
        require(
            msg.sender == IAccount(agreement.borrowerAccount.addr).getOwner(agreement.borrowerAccount.parameters),
            "exitPosition: sender!=borrower"
        );

        // All asset management must be done within this call, else bk would need to have asset-specific knowledge.
        IPosition position = IPosition(agreement.position.addr);
        uint256 closedAmount = position.close(msg.sender, agreement);

        ( uint256 cost) = IAssessor(agreement.assessor.addr).getCost(agreement);

        uint256 lenderOwed = agreement.loanAmount;
        uint256 distributeValue;
        // If cost asset is same erc20 as loan asset.
            lenderOwed += cost;
            distributeValue = msg.value;

        position.distribute{value: distributeValue}(msg.sender, lenderOwed, agreement);

        

        // Marks position as closed from Bookkeeper pov.
        position.transferContract(msg.sender);
    }

    // NOTE will need to implement an unkick function to enable soft or partial liquidations.
    function kick(
        SignedBlueprint calldata agreementBlueprint
    ) external nonReentrant verifySignature(agreementBlueprint) {
        (, bytes memory blueprintData) = unpackDataField(agreementBlueprint.blueprint.data);
        // require(blueprintDataType == bytes1(uint8(BlueprintDataType.AGREEMENT)), "BKKIBDT"); // decoding will fail
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));
        IPosition position = IPosition(agreement.position.addr);
        require(LibBookkeeper.isLiquidatable(agreement), "kick: not liquidatable");

        if (kicked[agreementBlueprint.blueprintHash] > 0) {
            revert("kick: already kicked");
        }
        kicked[agreementBlueprint.blueprintHash] = 1;


        IAccount(agreement.borrowerAccount.addr).unloadToPosition(
            agreement.position.addr,
            agreement.collAsset,
            agreement.collAmount,
            agreement.borrowerAccount.parameters
        );

        // Transfer ownership of the position to the liquidator, which includes collateral.
        position.transferContract(agreement.liquidator.addr);
        emit LiquidationKicked(agreement.liquidator.addr, agreement.position.addr);

        // Allow liquidator to react to kick.
        ILiquidator(agreement.liquidator.addr).receiveKick(msg.sender, agreement);
    }

    // NOTE this function succinctly represents a lot of the inefficiency of a plugin system design.
    function _createFundEnterPosition(Agreement memory agreement) private {
        (bool success, bytes memory data) = agreement.factory.call(abi.encodeWithSignature("createClone()"));
        require(success, "BKFCP");
        agreement.position.addr = abi.decode(data, (address));
        IAccount(agreement.lenderAccount.addr).unloadToPosition(
            agreement.position.addr,
            agreement.loanAsset,
            agreement.loanAmount,
            agreement.lenderAccount.parameters
        );
        // NOTE lots of gas savings if collateral can be kept in borrower account until absolutely necessary.
        IPosition(agreement.position.addr).deploy(
            agreement.loanAsset,
            agreement.loanAmount,
            agreement.position.parameters
        );
    }

    // TODO implement the verification

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

    // // fallback and receive revert by default. helpful to make reversion reason explicit?
    // fallback() external payable {
    //     revert("fallback function deactivated");
    // }

    // receive() external payable {
    //     revert("receive function deactivated");
    // }
}
