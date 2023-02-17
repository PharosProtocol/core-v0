// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * An account holding Lender capital that can be taken as a loan. A Supply Account has only
 * one lender, but each lender can have an arbitrary amount of Supply Accounts.
 * Can accept any erc20 asset, though it may not be useable.
 * Assets are pushed/pulled by Lender and Term Sheet.
 *
 * NOTE: "The automatic getters that are made for structs return all members in the struct except for members that are mappings and arrays"
 */
struct SupplyAccount {
    // bytes32 id; // redundant
    address lender;
    // Term sheets with which *new* positions can be opened.
    bytes32[] allowedTermSheets;
    // Current balance of assets.
    mapping(address => uint256) assets;
}

// enum status;

/**
 *
 */
contract SupplyAccountRegistry {
    event SupplyAccountCreated(address, bytes32);
    event SupplyAssetAdded(bytes32, address, uint256);
    event SupplyAssetRemoved(bytes32, address, uint256);

    mapping(bytes32 => SupplyAccount) private supplyAccounts; // Disable getters/setters
    uint256 public supplyAccountCount;
    // mapping(address => bytes32[]) lenderSupplyAccounts;

    function createSupplyAccount(
        bytes32 id,
        bytes32[] calldata termSheets,
        address[] calldata assets,
        uint256[] calldata amounts
    ) public {
        require(supplyAccounts[id].lender == address(0));
        // supplyAccounts[id] = SupplyAccount({lender: msg.sender, allowedTermSheets: termSheets});
        SupplyAccount storage supplyAccount = supplyAccounts[id];
        supplyAccount.lender = msg.sender;
        supplyAccount.allowedTermSheets = termSheets;
        supplyAccountCount++;
        emit SupplyAccountCreated(msg.sender, id);
        addSupplyAssets(id, assets, amounts);
    }

    function addSupplyAssets(bytes32 id, address[] calldata assets, uint256[] calldata amounts) public {
        require(supplyAccounts[id].lender == msg.sender);
        for (uint256 i; i < assets.length; i++) {
            supplyAccounts[id].assets[assets[i]] += amounts[i];
            require(IERC20(assets[i]).transferFrom(msg.sender, address(this), amounts[i]));
            emit SupplyAssetAdded(id, assets[i], amounts[i]);
        }
    }

    function removeSupplyAssets(bytes32 id, address[] calldata assets, uint256[] calldata amounts) public {
        require(supplyAccounts[id].lender == msg.sender);
        for (uint256 i; i < assets.length; i++) {
            supplyAccounts[id].assets[assets[i]] -= amounts[i]; // includes overflow check.
            require(IERC20(assets[i]).transfer(msg.sender, amounts[i]));
            emit SupplyAssetRemoved(id, assets[i], amounts[i]);
        }
    }

    function setAllowedTermSheets(bytes32 id, bytes32[] calldata termSheets) public {
        require(supplyAccounts[id].lender == msg.sender);
        supplyAccounts[id].allowedTermSheets = termSheets;
    }

    function decrementSupplyAssets(bytes32 id, address asset, uint256 amount) internal {
        supplyAccounts[id].assets[asset] -= amount; // includes overflow check.
    }

    function incrementSupplyAssets(bytes32 id, address asset, uint256 amount) internal {
        supplyAccounts[id].assets[asset] += amount;
    }

    /* Getters */
    function getAccountLender(bytes32 id) public view returns (address) {
        return supplyAccounts[id].lender;
    }

    function getAccountAssetAmount(bytes32 id, address asset) public view returns (uint256) {
        return supplyAccounts[id].assets[asset];
    }

    // TODO: This should be more efficient.
    function isAcceptableTermSheet(bytes32 id, bytes32 termSheet) public view returns (bool) {
        for (uint256 i = 0; i < supplyAccounts[id].allowedTermSheets.length; i++) {
            if (termSheet == supplyAccounts[id].allowedTermSheets[i]) {
                return true;
            }
        }
        return false;
    }
}
