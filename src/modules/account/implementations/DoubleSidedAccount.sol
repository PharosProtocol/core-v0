// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/LibUtil.sol";
import "src/C.sol";

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IAccount} from "src/modules/account/IAccount.sol";

/**
 * Account for holding ETH and ERC20 assets, to use for either lending or borrowing through an Agreement.
 * ~ Not compatible with other asset types ~
 */
contract DoubleSidedAccount is AccessControl, IAccount {
    bytes32 internal constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");

    struct Parameters {
        address owner;
        // An owner-unique id for this account.
        bytes32 ownerAccountSalt;
    }

    event AssetAdded(address owner, bytes32 salt, Asset asset, uint256 amount);
    event AssetRemoved(address owner, bytes32 salt, Asset asset, uint256 amount);

    mapping(bytes32 => mapping(bytes32 => uint256)) private accounts; // account id => asset hash => amount

    constructor() {
        _grantRole(PROTOCOL_ROLE, C.MODULEND_ADDR);
    }

    function addAssetFrom(address from, Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        payable
        override
    {
        Parameters memory params = abi.decode(parameters, (Parameters));

        // require(msg.sender == params.owner);
        bytes32 accountId = _generateId(params.owner, params.ownerAccountSalt);

        // Handle ETH.
        if (Utils.isEth(asset)) {
            // require(msg.sender == from);
            require(msg.value == amount, "addAssetFrom: eth value does not match amount"); // NOTE how protective to be about over sending?
        }
        // Handle ERC20.
        else if (asset.standard == ERC20_STANDARD) {
            Utils.transferAsset(from, address(this), asset, amount);
        }
        // TODO implement ERC721, ERC1155 ??
        else {
            revert("addAssetFrom: unsupported asset");
        }
        accounts[accountId][keccak256(abi.encode(asset))] += amount;

        emit AssetAdded(params.owner, params.ownerAccountSalt, asset, amount);
    }

    function removeAsset(Asset calldata asset, uint256 amount, bytes calldata parameters) external override {
        Parameters memory params = abi.decode(parameters, (Parameters));

        require(msg.sender == params.owner);
        bytes32 accountId = _generateId(params.owner, params.ownerAccountSalt);

        // Handle ETH and ERC20.
        if (Utils.isEth(asset) || asset.standard == ERC20_STANDARD) {
            Utils.transferAsset(address(this), msg.sender, asset, amount);
        }
        // TODO implement ERC721, ERC1155 ??
        else {
            revert("removeAsset: unsupported asset");
        }
        accounts[accountId][keccak256(abi.encode(asset))] -= amount; // verifies account balance is sufficient

        emit AssetRemoved(params.owner, params.ownerAccountSalt, asset, amount);
    }

    // NOTE could bypass need hre (and other modules) for PROTOCOL_ROLE by verifying signed agreement and tracking
    //      which have already been processed.
    function capitalizePosition(
        address position,
        Asset calldata loanAsset,
        uint256 loanAmount,
        bytes calldata lenderAccountParameters,
        Asset calldata collateralAsset,
        uint256 collateralAmount,
        bytes calldata borrowerAccountParameters
    ) external override onlyRole(PROTOCOL_ROLE) {
        Parameters memory lenderParams = abi.decode(lenderAccountParameters, (Parameters));
        Parameters memory borrowerParams = abi.decode(borrowerAccountParameters, (Parameters));

        bytes32 lenderAccountId = _generateId(lenderParams.owner, lenderParams.ownerAccountSalt);
        bytes32 borrowerAccountId = _generateId(borrowerParams.owner, borrowerParams.ownerAccountSalt);

        Utils.transferAsset(address(this), position, loanAsset, loanAmount);
        accounts[lenderAccountId][keccak256(abi.encode(loanAsset))] -= loanAmount;
        Utils.transferAsset(address(this), position, collateralAsset, collateralAmount);
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
        bytes32 accountId = _generateId(params.owner, params.ownerAccountSalt);
        return accounts[accountId][keccak256(abi.encode(asset))];
    }

    function _generateId(address owner, bytes32 salt) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, salt));
    }
}
