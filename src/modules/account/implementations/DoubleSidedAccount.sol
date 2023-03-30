// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

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
contract DoubleSidedAccount is AccessControl {
    bytes32 internal constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");

    event AssetAdded(bytes32 accountId, Asset asset, uint256 amount);
    event AssetRemoved(bytes32 accountId, Asset asset, uint256 amount);

    mapping(bytes32 => mapping(bytes32 => uint256)) private accounts; // account id => asset hash => amount

    constructor() {
        _grantRole(PROTOCOL_ROLE, C.MODULEND_ADDR);
    }

    function addAsset(Asset calldata asset, uint256 amount, bytes calldata parameters) external payable {
        Parameters memory params = abi.decode(parameters, (Parameters));

        // require(msg.sender == params.owner);
        bytes32 accountId = _generateId(params.owner, params.ownerAccountSalt);

        // Handle ETH.
        if (asset.standard == ETH_STANDARD) {
            require(msg.value == amount); // NOTE how protective to be about over sending?
        }
        // Handle ERC20.
        else if (asset.standard == ERC20_STANDARD) {
            Utils.transferAsset(msg.sender, address(this), asset, amount);
        }
        // TODO implement ERC721, ERC1155 ??
        else {
            revert("addAsset: unsupported asset");
        }
        accounts[accountId][keccak256(abi.encode(asset))] += amount;

        emit AssetAdded(accountId, asset, amount);
    }

    function removeAsset(Asset calldata asset, uint256 amount, bytes calldata parameters) external {
        Parameters memory params = abi.decode(parameters, (Parameters));

        require(msg.sender == params.owner);
        bytes32 accountId = _generateId(params.owner, params.ownerAccountSalt);

        // Handle ETH and ERC20.
        if (asset.standard == ETH_STANDARD || asset.standard == ERC20_STANDARD) {
            Utils.transferAsset(address(this), msg.sender, asset, amount);
        }
        // TODO implement ERC721, ERC1155 ??
        else {
            revert("removeAsset: unsupported asset");
        }
        accounts[accountId][keccak256(abi.encode(asset))] -= amount; // verifies account balance is sufficient

        emit AssetRemoved(accountId, asset, amount);
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
        Parameters memory lenderParams = abi.decode(lenderAccountParameters, (Parameters));
        Parameters memory borrowerParams = abi.decode(borrowerAccountParameters, (Parameters));

        bytes32 lenderAccountId = _generateId(lenderParams.owner, lenderParams.ownerAccountSalt);
        bytes32 borrowerAccountId = _generateId(borrowerParams.owner, borrowerParams.ownerAccountSalt);

        Utils.transferAsset(address(this), position, loanAsset, loanAmount);
        accounts[lenderAccountId][keccak256(abi.encode(loanAsset))] -= loanAmount;
        Utils.transferAsset(address(this), position, collateralAsset, collateralAmount);
        accounts[borrowerAccountId][keccak256(abi.encode(collateralAsset))] -= collateralAmount;
    }

    function getOwner(bytes calldata parameters) external pure returns (address) {
        return abi.decode(parameters, (Parameters)).owner;
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
