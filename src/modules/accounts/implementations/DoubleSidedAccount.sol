// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/libraries/LibUtil.sol";
import "src/protocol/C.sol";

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

struct Parameters {
    address owner;
    // An owner-unique id for this account.
    bytes32 ownerAccountSalt;
}

/**
 * Account for holding ETH and ERC20 assets, to use for either lending or borrowing through an Agreement.
 * ~ Not compatible with other asset types ~
 */
contract DoubleSidedAccount {
    bytes32 internal constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");

    event AssetsAdded(bytes32 accountId, Asset[] assets, uint256[] amounts);
    event AssetsRemoved(bytes32 accountId, Asset[] assets, uint256[] amounts);

    mapping(bytes32 => mapping(bytes32 => uint256)) private accounts; // account id => asset hash => amount

    constructor() {
        _grantRole(PROTOCOL_ROLE, C.MODULEND_ADDR);
    }

    function addAssets(Asset[] calldata assets, uint256[] calldata amounts, bytes calldata parameters)
        external
        payable
    {
        Parameters memory params = abi.decode(parameters, (Parameters));

        require(msg.sender == params.owner);
        bytes32 accountId = _generateId(params.owner, params.ownerAccountSalt);

        for (uint256 i; i < assets.length; i++) {
            // Handle ETH.
            if (assets[i].standard == ETH_STANDARD) {
                require(msg.value == amounts[i]); // NOTE how protective to be about over sending?
            }
            // Handle ERC20.
            else if (assets[i].standard == ERC20_STANDARD) {
                Utils.transferAsset(msg.sender, address(this), assets[i], amounts[i]);
            }
            // TODO implement ERC721, ERC1155 ??
            else {
                revert("addAssets: unsupported asset");
            }
            accounts[accountId][keccak256(abi.encode(assets[i]))] += amounts[i];
        }

        emit AssetsAdded(accountId, assets, amounts);
    }

    function removeAssets(Asset[] calldata assets, uint256[] calldata amounts, bytes calldata parameters) external {
        Parameters memory params = abi.decode(parameters, (Parameters));

        require(msg.sender == params.owner);
        bytes32 accountId = _generateId(params.owner, params.ownerAccountSalt);

        for (uint256 i; i < assets.length; i++) {
            // Handle ETH and ERC20.
            if (assets[i].standard == ETH_STANDARD || assets[i].standard == ERC20_STANDARD) {
                Utils.transferAsset(address(this), msg.sender, assets[i], amounts[i]);
            }
            // TODO implement ERC721, ERC1155 ??
            else {
                revert("addAssets: unsupported asset");
            }
            accounts[accountId][keccak256(abi.encode(assets[i]))] -= amounts[i]; // verifies account balance is sufficient
        }

        emit AssetsRemoved(accountId, assets, amounts);
    }

    function capitalizePosition(
        address position,
        Asset calldata loanAsset,
        uint256 loanAmount,
        bytes calldata lenderAccountParameters,
        Asset calldata collateralAsset,
        uint256 collateralAmount,
        bytes calldata borrowerAccountParameters
    ) external onlyRole(PROTOCOL_ROLE) {
        Parameters memory lenderParams = abi.decode(parameters, (lenderAccountParameters));
        Parameters memory borrowerParams = abi.decode(parameters, (borrowerAccountParameters));

        bytes32 lenderAccountId = _generateId(lenderParams.owner, lenderParams.ownerAccountSalt);
        bytes32 borrowerAccountId = _generateId(borrowerParams.owner, borrowerParams.ownerAccountSalt);

        Utils.transferAsset(address(this), position, loanAsset, loanAmount);
        accounts[lenderAccountId][keccak256(abi.encode(loanAsset))] -= loanAmount;
        Utils.transferAsset(address(this), position, collateralAsset, collateralAmount);
        accounts[borrowerAccountId][keccak256(abi.encode(collateralAsset))] -= collateralAmount;
    }

    function getBalances(Asset[] calldata assets, bytes calldata parameters)
        external
        view
        returns (uint256[] memory amounts)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));

        bytes32 accountId = _generateId(params.owner, params.ownerAccountSalt);

        amounts = new uint256[](assets.length);
        for (uint256 i; i < assets.length; i++) {
            amounts[i] = accounts[accountId][keccak256(abi.encode(assets[i]))];
        }
        return amounts;
    }

    function _generateId(address owner, bytes32 salt) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, salt));
    }
}
