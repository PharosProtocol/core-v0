// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/LibUtil.sol";
import {C} from "src/C.sol";

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IAccount} from "src/modules/account/IAccount.sol";

/**
 * Account for holding ETH and ERC20 assets, to use for either lending or borrowing through an Agreement.
 * ~ Not compatible with other asset types ~
 */
contract DoubleSidedAccount is AccessControl, IAccount {
    bytes32 internal constant BOOKKEEPER_ROLE = keccak256("BOOKKEEPER_ROLE");

    struct Parameters {
        address owner;
        // An owner-unique id for this account.
        bytes32 salt;
    }

    event AssetAdded(address owner, bytes parameters, Asset asset, uint256 amount);
    event AssetRemoved(address owner, bytes parameters, Asset asset, uint256 amount);

    mapping(bytes32 => mapping(bytes32 => uint256)) private accounts; // account id => asset hash => amount

    constructor() {
        _grantRole(BOOKKEEPER_ROLE, C.MODULEND_ADDR);
    }

    function addAsset(Asset calldata asset, uint256 amount, bytes calldata parameters) external payable override {
        _addAsset(msg.sender, asset, amount, parameters);
    }

    /// @dev the bookkeeper is the only actor that is allowed to act as a delegate. Else approved funds are at risk.
    function addAssetBookkeeper(address from, Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        payable
        override
        onlyRole(BOOKKEEPER_ROLE)
    {
        _addAsset(from, asset, amount, parameters);
    }

    function _addAsset(address from, Asset calldata asset, uint256 amount, bytes calldata parameters) private {
        Parameters memory params = abi.decode(parameters, (Parameters));

        // require(from == params.owner);
        bytes32 accountId = _generateId(params.owner, params.salt);

        accounts[accountId][keccak256(abi.encode(asset))] += amount;
        Utils.receiveAsset(from, asset, amount); // ETH and ERC20 implemented

        emit AssetAdded(params.owner, parameters, asset, amount);
    }

    function removeAsset(Asset calldata asset, uint256 amount, bytes calldata parameters) external override {
        Parameters memory params = abi.decode(parameters, (Parameters));

        require(msg.sender == params.owner, "removeAsset: not owner");
        bytes32 accountId = _generateId(params.owner, params.salt);

        accounts[accountId][keccak256(abi.encode(asset))] -= amount; // verifies account balance is sufficient
        Utils.sendAsset(msg.sender, asset, amount); // ETH and ERC20 implemented

        emit AssetRemoved(params.owner, parameters, asset, amount);
    }

    // NOTE could bypass need hre (and other modules) for BOOKKEEPER_ROLE by verifying signed agreement and tracking
    //      which have already been processed.
    function capitalizePosition(
        address position,
        Asset calldata loanAsset,
        uint256 loanAmount,
        bytes calldata lenderAccountParameters,
        Asset calldata collateralAsset,
        uint256 collateralAmount,
        bytes calldata borrowerAccountParameters
    ) external override onlyRole(BOOKKEEPER_ROLE) {
        Parameters memory lenderParams = abi.decode(lenderAccountParameters, (Parameters));
        Parameters memory borrowerParams = abi.decode(borrowerAccountParameters, (Parameters));

        bytes32 lenderAccountId = _generateId(lenderParams.owner, lenderParams.salt);
        bytes32 borrowerAccountId = _generateId(borrowerParams.owner, borrowerParams.salt);

        Utils.sendAsset(position, loanAsset, loanAmount);
        accounts[lenderAccountId][keccak256(abi.encode(loanAsset))] -= loanAmount;
        Utils.sendAsset(position, collateralAsset, collateralAmount);
        accounts[borrowerAccountId][keccak256(abi.encode(collateralAsset))] -= collateralAmount;
    }

    function getOwner(bytes calldata parameters) external pure override returns (address) {
        return abi.decode(parameters, (Parameters)).owner;
    }

    function getBalance(Asset calldata asset, bytes calldata parameters)
        external
        view
        override
        returns (uint256 amounts)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 accountId = _generateId(params.owner, params.salt);
        return accounts[accountId][keccak256(abi.encode(asset))];
    }

    function _generateId(address owner, bytes32 salt) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, salt));
    }
}
