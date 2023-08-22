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
import {Asset, LibUtils, ETH_STANDARD} from "src/libraries/LibUtils.sol";

// NOTE bookkeeper will be far more difficult to update / fix / expand than any of the plugins. For this reason
//      simplicity should be aggressively pursued.
//      It should also *not* have any asset transfer logic, bc then it requires compatibility with any assets that
//      plugins might implement. The exception is cost assessment, which is known to be in erc20/eth.

// NOTE SECURITY bookkeeper cannot make any delegate external calls to unknown code bc it contains shared state.
//      extreme caution should be taken for standard external calls.
// NOTE this means no calls to freighters.
// NOTE it also means oracles cannot be implemented as libraries...? UNLESS USING STATICCALL

contract Bookkeeper is Tractor, ReentrancyGuard {
    enum BlueprintDataType {
        NULL,
        ORDER,
        AGREEMENT
    }

    string public constant PROTOCOL_NAME = "pharos";
    string public constant PROTOCOL_VERSION = "0.2.0";

    // AUDIT: reading/writing uint256 more efficient than bool?
    // Map indicating if a position has already been kicked.
    mapping(bytes32 => uint256) public kicked; // blueprintHash => 0/1 bool

    event OrderFilled(SignedBlueprint agreement, bytes32 orderBlueprintHash, address taker);
    event PositionExited(SignedBlueprint agreement, Asset costAsset, uint256 cost);
    event LiquidationKicked(address liquidator, address position);

    constructor() Tractor(PROTOCOL_NAME, PROTOCOL_VERSION) {}

    // function addAssetsToPlugin() // port or terminal top up

    function fillOrder(
        Fill calldata fill,
        SignedBlueprint calldata orderBlueprint
    ) external nonReentrant verifySignature(orderBlueprint) {
        // decode order blueprint data and ensure blueprint metadata is valid pairing with embedded data
        (bytes1 blueprintDataType, bytes memory blueprintData) = unpackDataField(orderBlueprint.blueprint.data);
        require(uint8(blueprintDataType) == uint8(BlueprintDataType.ORDER), "BKDTMM");

        // Verify publishers own accounts. May or may not be EOA.
        require(msg.sender == IAccount(fill.account.addr).owner(), "fillOrder: Taker != msg.sender");
        Order memory order = abi.decode(blueprintData, (Order));
        require(orderBlueprint.blueprint.publisher == IAccount(order.account.addr).owner(), "BKPOMM");
        if (order.fillers.length > 0) {
            require(order.fillers[fill.takerIdx] == msg.sender, "Bookkeeper: Invalid taker");
        }

        LibBookkeeper.verifyFill(fill, order);
        Agreement memory agreement = LibBookkeeper.agreementFromOrder(fill, order);

        uint256 loanValue = IOracle(agreement.loanOracle.addr).getResistantValue(
            agreement.loanAmount,
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
        agreement.collAmount = IOracle(agreement.collOracle.addr).getResistantAmount(
            collateralValue,
            agreement.collOracle.parameters
        );
        // Set Position data that cannot be computed off chain by caller.
        agreement.deploymentTime = block.timestamp;

        _createFundEnterPosition(agreement);

        SignedBlueprint memory signedBlueprint = _signAgreement(agreement);
        emit OrderFilled(signedBlueprint, orderBlueprint.blueprintHash, msg.sender);
    }

    // NOTE AUDIT verify works with ETH
    // NOTE CEI?
    function exitPosition(
        SignedBlueprint calldata agreementBlueprint
    ) external payable nonReentrant verifySignature(agreementBlueprint) {
        (bytes1 blueprintDataType, bytes memory blueprintData) = unpackDataField(agreementBlueprint.blueprint.data);
        require(blueprintDataType == bytes1(uint8(BlueprintDataType.AGREEMENT)), "exitPosition: Invalid data type");
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));
        require(msg.sender == IAccount(agreement.borrowerAccount.addr).owner(), "exitPosition: sender!=borrower");

        // All asset management must be done within this call, else bk would need to have asset-specific knowledge.
        IPosition position = IPosition(agreement.position.addr);
        uint256 closedAmount = position.close(msg.sender, agreement);

        uint256 loanAssetAmountOwed = agreement.loanAmount;

        // f = IFreighter(agreement.loanFreighter.addr);
        t = IPosition(agreement.position.addr);
        lp = IAccount(agreement.lenderAccount.addr);

        (PluginRef memory costFreighter, Asset memory costAsset, uint256 costAmount) = IAssessor(
            agreement.assessor.addr
        ).getCost(agreement, closedAmount);

        // Expected use with ETH and ERC20s
        if (isSameAssetConfig(loanAsset, costAsset)) {
            loanAssetAmountOwed += cost;
        } else {
            lp.pull(msg.sender, costFreighter, costAsset, costAmount, AssetState.PORT);
            lp.processReceipt(costFreighter, costAsset, costAmount, AssetState.USER, AssetState.PORT);
        }

        // If cost asset is same erc20 as loan asset.
        // if (LibUtils.isValidLoanAssetAsCost(agreement.loanAsset, costAsset)) {

        // NOTE two possible paradigms to impl here:
        // 1. Use preset amounts, found in agreement to determine position balance. This requires pos to static throughout life. This allows terminals to never need to pull.
        // 2. Use real time balances, which allows users to add/remove collateral from position. This requires pulling into terminals.

        // Pay lender.
        // Deficit loan asset comes from sender.
        if (closedAmount < loanAssetAmountOwed) {
            t.pull(
                msg.sender,
                agreement.loanFreighter,
                agreement.loanAsset,
                loanAssetAmountOwed - closedAmount,
                AssetState.TERMINAL_LOAN
            );
            t.processReceipt(
                agreement.loanFreighter,
                agreement.loanAsset,
                loanAssetAmountOwed - closedAmount,
                AssetState.USER,
                AssetState.TERMINAL_LOAN
            );
        }
        t.push(
            agreement.lenderAccount,
            agreement.loanFreighter,
            agreement.loanAsset,
            loanAssetAmountOwed,
            AssetState.TERMINAL_LOAN
        );
        lp.processReceipt(
            agreement.loanFreighter,
            agreement.loanAsset,
            loanAssetAmountOwed,
            AssetState.TERMINAL_LOAN,
            AssetState.PORT
        );

        // Excess loan asset goes to borrower.
        if (closeAmount > loanAssetAmountOwed) {
            t.push(
                agreement.borrowerAccount,
                agreement.loanFreighter,
                agreement.loanAsset,
                closeAmount - loanAssetAmountOwed,
                AssetState.TERMINAL_LOAN
            );
            lp.processReceipt(
                agreement.loanFreighter,
                agreement.loanAsset,
                closeAmount - loanAssetAmountOwed,
                AssetState.TERMINAL_LOAN,
                AssetState.PORT
            );
        }

        // All collateral asset goes to borrower.
        t.push(
            agreement.borrowerAccount,
            agreement.collFreighter,
            agreement.collAsset,
            agreement.collAmount,
            AssetState.TERMINAL_LOAN
        );
        lp.processReceipt(
            agreement.collFreighter,
            agreement.collAsset,
            agreement.collAmount,
            AssetState.TERMINAL_LOAN,
            AssetState.PORT
        );

        // SECURITY implications of position continuing to exist?
        // NOTE mostly unnecessary and not gas cheap.
        // // Marks position as closed from Bookkeeper pov.
        // position.transferContract(msg.sender);

        emit PositionExited(agreementBlueprint, costAsset, cost);
    }

    // NOTE will need to implement an unkick function to enable soft or partial liquidations.
    function kick(
        SignedBlueprint calldata agreementBlueprint
    ) external nonReentrant verifySignature(agreementBlueprint) {
        (, bytes memory blueprintData) = unpackDataField(agreementBlueprint.blueprint.data);
        // require(blueprintDataType == bytes1(uint8(BlueprintDataType.AGREEMENT)), "BKKIBDT"); // decoding will fail
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));
        IPosition position = IPosition(agreement.position.addr);
        if (kicked[agreementBlueprint.blueprintHash] > 0) {
            revert("kick: already kicked");
        }
        kicked[agreementBlueprint.blueprintHash] = 1;

        require(LibBookkeeper.isLiquidatable(agreement), "kick: not liquidatable");

        IAccount(agreement.borrowerAccount.addr).unloadToPosition(
            agreement.position.addr,
            agreement.collAsset,
            agreement.collAmount,
            true,
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
        IPosition position = IPosition(agreement.position.addr);
        IAccount(agreement.lenderAccount.addr).sendToPosition(
            agreement.position.addr,
            agreement.loanFreighter.addr,
            agreement.loanAsset,
            agreement.loanAmount,
            agreement.loanFreighter.parameters
        );
        position.processReceipt(
            agreement.loanFreighter,
            agreement.loanAsset,
            agreement.loanAmount,
            AssetState.PORT,
            AssetState.TERMINAL_LOAN
        );
        IAccount(agreement.borrowerAccount.addr).sendToPosition(
            agreement.position.addr,
            agreement.collFreighter.addr,
            agreement.collAsset,
            agreement.collAmount,
            agreement.collFreighter.parameters
        );
        position.processReceipt(
            agreement.collFreighter,
            agreement.collAsset,
            agreement.collAmount,
            AssetState.PORT,
            AssetState.TERMINAL_COLL
        );
        position.deploy(agreement);
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
