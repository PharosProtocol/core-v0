// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "forge-std/console.sol";

import "lib/tractor/Tractor.sol";
import "src/LibUtil.sol";

import {Order, Fill, Agreement, LibBookkeeper} from "src/bookkeeper/LibBookkeeper.sol";
import {C} from "src/C.sol";
import "src/interfaces/IOracle.sol";
import {IAccount} from "src/interfaces/IAccount.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {ILiquidator} from "src/interfaces/ILiquidator.sol";
import {Utils} from "src/LibUtil.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";

// NOTE bookkeeper will be far more difficult to update / fix / expand than any of the modules. For this reason
//      simplicity should be aggressively pursued.
//      It should also *not* have any asset transfer logic, bc then it requires compatibility with any assets that
//      modules might implement.

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
        ORDER,
        AGREEMENT
    }

    string constant PROTOCOL_NAME = "pharos";
    string constant PROTOCOL_VERSION = "1.0.0";

    event OrderFilled(SignedBlueprint agreement, bytes32 indexed blueprintHash, address indexed taker);
    event LiquidationKicked(address liquidator, address position);

    constructor() Tractor(PROTOCOL_NAME, PROTOCOL_VERSION) {}
    // receive() external {}
    // fallback() external {}

    function fillOrder(
        Fill calldata fill,
        SignedBlueprint calldata orderBlueprint,
        ModuleReference calldata takerAccount
    ) external verifySignature(orderBlueprint) {
        // decode order blueprint data and ensure blueprint metadata is valid pairing with embedded data
        (bytes1 blueprintDataType, bytes memory blueprintData) = unpackDataField(orderBlueprint.blueprint.data);
        require(uint8(blueprintDataType) == uint8(BlueprintDataType.ORDER), "BKDTMM");
        // console.log("blueprint data at decoding:");
        // console.logBytes(blueprintData);
        Order memory order = abi.decode(blueprintData, (Order));
        require(orderBlueprint.blueprint.publisher == Utils.getAccountOwner(order.account), "BKPOMM");
        if (order.takers.length > 0) {
            require(order.takers[fill.takerIdx] == msg.sender, "Bookkeeper: Invalid taker");
        }

        Agreement memory agreement = agreementFromOrder(fill, order);

        uint256 loanValue = IOracle(agreement.loanOracle.addr).getValue(
            agreement.loanAsset, agreement.loanAmount, agreement.loanOracle.parameters
        );
        uint256 collateralValue;

        if (order.isOffer) {
            agreement.lenderAccount = order.account;
            agreement.borrowerAccount = takerAccount;
            collateralValue = loanValue * fill.borrowerConfig.initCollateralRatio / C.RATIO_FACTOR;
            agreement.position.parameters = fill.borrowerConfig.positionParameters;
        } else {
            agreement.lenderAccount = takerAccount;
            agreement.borrowerAccount = order.account;
            collateralValue = loanValue * order.borrowerConfig.initCollateralRatio / C.RATIO_FACTOR;
            agreement.position.parameters = order.borrowerConfig.positionParameters;
        }
        agreement.collateralAmount = IOracle(agreement.collateralOracle.addr).getAmount(
            agreement.collAsset, collateralValue, agreement.collateralOracle.parameters
        );
        // Set Position data that cannot be computed off chain by caller.
        agreement.deploymentTime = block.timestamp;

        // console.log("loanAmount: %s", agreement.loanAmount);
        // console.log("collateralAmount: %s", agreement.collateralAmount);

        createFundEnterPosition(agreement);

        // console.log("agreement encoded:");
        // console.logBytes(abi.encode(agreement));

        SignedBlueprint memory signedBlueprint = signAgreement(agreement);
        emit OrderFilled(signedBlueprint, orderBlueprint.blueprintHash, msg.sender);
    }

    // NOTE this function succinctly represents a lot of the inefficiency of a module system design.
    function createFundEnterPosition(Agreement memory agreement) private {
        (bool success, bytes memory data) = agreement.position.addr.call(abi.encodeWithSignature("createPosition()"));
        require(success, "BKFCP");
        agreement.position.addr = abi.decode(data, (address));
        IAccount(agreement.lenderAccount.addr).transferToPosition(
            agreement.position.addr,
            agreement.loanAsset,
            agreement.loanAmount,
            false,
            agreement.lenderAccount.parameters
        );
        // NOTE lots of gas savings if collateral can be kept in borrower account until absolutely necessary.
        IAccount(agreement.borrowerAccount.addr).lockCollateral(
            agreement.collAsset, agreement.collateralAmount, agreement.borrowerAccount.parameters
        );
        IPosition(agreement.position.addr).deploy(
            agreement.loanAsset, agreement.loanAmount, agreement.position.parameters
        );
    }

    /// @dev assumes compatibility between match, offer, and request already verified.
    function agreementFromOrder(Fill calldata fill, Order memory order)
        private
        pure
        returns (Agreement memory agreement)
    {
        // NOTE this is prly not gas efficient bc of zero -> non-zero changes...
        agreement.maxDuration = order.maxDuration;
        agreement.assessor = order.assessor;
        agreement.liquidator = order.liquidator;

        agreement.loanAsset = order.loanAssets[fill.loanAssetIdx];
        agreement.loanOracle = order.loanOracles[fill.loanOracleIdx];
        agreement.collAsset = order.collAssets[fill.collAssetIdx];
        agreement.collateralOracle = order.collateralOracles[fill.collateralOracleIdx];
        // NOTE confusion here (and everywhere) on position address vs factory address. Naming fix?
        agreement.factory = order.factories[fill.factoryIdx];
        agreement.position.addr = order.factories[fill.factoryIdx];

        require(fill.loanAmount >= order.minLoanAmounts[fill.loanAssetIdx], "Bookkeeper: fill loan amount too small");
        agreement.loanAmount = fill.loanAmount;
    }

    // NOTE CEI?
    function exitPosition(SignedBlueprint calldata agreementBlueprint)
        external
        payable
        verifySignature(agreementBlueprint)
    {
        (bytes1 blueprintDataType, bytes memory blueprintData) = unpackDataField(agreementBlueprint.blueprint.data);
        require(
            blueprintDataType == bytes1(uint8(BlueprintDataType.AGREEMENT)), "Bookkeeper: Invalid blueprint data type"
        );
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));
        require(
            msg.sender == IAccount(agreement.borrowerAccount.addr).getOwner(agreement.borrowerAccount.parameters),
            "Bookkeeper: Only borrower can exit position without liquidation"
        );

        // All asset management must be done within this call, else bk would need to have asset-specific knowledge.
        IPosition position = IPosition(agreement.position.addr);

        position.exit(agreement, agreement.position.parameters);

        IAccount(agreement.borrowerAccount.addr).unlockCollateral(
            agreement.collAsset, agreement.collateralAmount, agreement.borrowerAccount.parameters
        );

        // Marks position as closed from Bookkeeper pov.
        position.transferContract(msg.sender);
    }

    // NOTE CEI?
    // @notice Borrower directly pays lender and claim control over position MPC.
    function detachPosition(SignedBlueprint calldata agreementBlueprint)
        external
        payable
        verifySignature(agreementBlueprint)
    {
        (bytes1 blueprintDataType, bytes memory blueprintData) = unpackDataField(agreementBlueprint.blueprint.data);
        require(
            blueprintDataType == bytes1(uint8(BlueprintDataType.AGREEMENT)), "Bookkeeper: Invalid blueprint data type"
        );
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));
        require(
            msg.sender == IAccount(agreement.borrowerAccount.addr).getOwner(agreement.borrowerAccount.parameters),
            "Bookkeeper: Only borrower can exit position without liquidation"
        );

        uint256 owedAmount = IAssessor(agreement.assessor.addr).getCost(agreement);

        // Borrower must pay difference directly if there is not enough value to pay Lender.
        // Amount is not a compatible concept with all agreements, in those cases unpaid amount should be 0.
        if (owedAmount > 0) {
            // Requires sender to have already approved account contract to use necessary assets.
            IAccount(payable(agreement.lenderAccount.addr)).sideLoad{value: msg.value}(
                msg.sender, agreement.loanAsset, owedAmount, agreement.lenderAccount.parameters
            );
        }

        IAccount(agreement.borrowerAccount.addr).unlockCollateral(
            agreement.collAsset, agreement.collateralAmount, agreement.borrowerAccount.parameters
        );

        IPosition(agreement.position.addr).transferContract(agreement.liquidator.addr);
    }

    function kick(SignedBlueprint calldata agreementBlueprint) external verifySignature(agreementBlueprint) {
        (bytes1 blueprintDataType, bytes memory blueprintData) = unpackDataField(agreementBlueprint.blueprint.data);
        require(blueprintDataType == bytes1(uint8(BlueprintDataType.AGREEMENT)), "BKKIBDT");
        Agreement memory agreement = abi.decode(blueprintData, (Agreement));
        IPosition position = IPosition(agreement.position.addr);

        // // Cannot liquidate if not owned by protocol (liquidating/liquidated/exited).
        // require(position.hasRole(C.CONTROLLER_ROLE, address(this)), "Position not owned by protocol");

        require(LibBookkeeper.isLiquidatable(agreement), "Bookkeeper: Position is not liquidatable");

        IAccount(agreement.lenderAccount.addr).transferToPosition(
            agreement.position.addr, agreement.loanAsset, agreement.loanAmount, true, agreement.lenderAccount.parameters
        );

        // Transfer ownership of the position to the liquidator, which includes collateral.
        position.transferContract(agreement.liquidator.addr);
        // Kick the position to begin liquidation.
        // ILiquidator(agreement.liquidator.addr).takeKick(agreementBlueprint.blueprintHash);
        emit LiquidationKicked(agreement.liquidator.addr, agreement.position.addr);
    }

    function signAgreement(Agreement memory agreement) private returns (SignedBlueprint memory signedBlueprint) {
        // Create blueprint to store signed Agreement off chain via events.
        signedBlueprint.blueprint.publisher = address(this);
        signedBlueprint.blueprint.data =
            packDataField(bytes1(uint8(BlueprintDataType.AGREEMENT)), abi.encode(agreement));
        signedBlueprint.blueprint.endTime = type(uint256).max;
        signedBlueprint.blueprintHash = getBlueprintHash(signedBlueprint.blueprint);
        // NOTE: Security: Is is possible to intentionally manufacture a blueprint with different data that creates the same hash?
        signBlueprint(signedBlueprint.blueprintHash);
        // publishBlueprint(signedBlueprint); // These verifiable blueprints will be used to interact with positions.
    }

    // NOTE why is this not public by EIP712 OZ impl default? What are the implications of exposing it here?
    function getTypedDataHash(bytes32 structHash) external view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }
}
