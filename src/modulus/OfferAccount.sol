// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * An account holding Lender capital that can be taken as a loan. An Offer Account has only
 * one lender, but each lender can have an arbitrary amount of Offer Accounts.
 * Can accept any erc20 asset, though it may not be useable.
 * Assets are pushed/pulled by Lender and Term Sheet.
 *
 * NOTE: "The automatic getters that are made for structs return all members in the struct except for members that are mappings and arrays"
 */
struct OfferAccount {
    address lender;
    // Term sheets with which *new* positions can be opened.
    bytes32[] allowedTermSheets;
    // Current balance of assets that can be loaned out.
    mapping(address => uint256) assets;

    // Borrowers that can take this Offer.
    address[] allowedBorrowers;
    // Terminals that can be deployed into.
    address[] allowedTerminals;
    // Collateral assets that can be provided.
    address[] allowedCollateralAssets;
}

// enum status;

/**
 *
 */
contract OfferAccountRegistry {
    event OfferAccountCreated(address, bytes32);
    event OfferAssetsAdded(bytes32, address, uint256);
    event OfferAssetsRemoved(bytes32, address, uint256);

    mapping(bytes32 => OfferAccount) private accounts; // Disable getters/setters
    uint256 public accountCount;
    // mapping(address => bytes32[]) lenderOfferAccounts;

    function createOfferAccount(
        bytes32 id,
        bytes32[] calldata termSheets,
        address[] calldata assets,
        uint256[] calldata amounts
    ) public {
        require(accounts[id].lender == address(0));
        // accounts[id] = OfferAccount({lender: msg.sender, allowedTermSheets: termSheets});
        OfferAccount storage account = accounts[id];
        account.lender = msg.sender;
        setOfferTermSheets(id, termSheets);
        accountCount++;
        emit OfferAccountCreated(msg.sender, id);
        addOfferAssets(id, assets, amounts);
    }

    function setOfferTermSheets(bytes32 id, bytes32[] calldata termSheets) public {
        // NOTE: Do we want to do checks here and guarantee that all Offers are valid? Or at position creation?
        // for (uint256 i; i < termSheets.length; i++) {
        //     // Check that term sheet is compatible with offer.

        // }
        accounts[id].allowedTermSheets = termSheets;
    }

    function addOfferAssets(bytes32 id, address[] calldata assets, uint256[] calldata amounts) public {
        require(accounts[id].lender == msg.sender);
        for (uint256 i; i < assets.length; i++) {
            accounts[id].assets[assets[i]] += amounts[i];
            require(IERC20(assets[i]).transferFrom(msg.sender, address(this), amounts[i]));
            emit OfferAssetsAdded(id, assets[i], amounts[i]);
        }
    }

    function removeOfferAssets(bytes32 id, address[] calldata assets, uint256[] calldata amounts) public {
        require(accounts[id].lender == msg.sender);
        for (uint256 i; i < assets.length; i++) {
            accounts[id].assets[assets[i]] -= amounts[i]; // includes overflow check.
            require(IERC20(assets[i]).transfer(msg.sender, amounts[i]));
            emit OfferAssetsRemoved(id, assets[i], amounts[i]);
        }
    }

    function setAllowedTermSheets(bytes32 id, bytes32[] calldata termSheets) public {
        require(accounts[id].lender == msg.sender);
        accounts[id].allowedTermSheets = termSheets;
    }

    function decrementOfferAssets(bytes32 id, address asset, uint256 amount) internal {
        accounts[id].assets[asset] -= amount; // includes overflow check.
    }

    function incrementOfferAssets(bytes32 id, address asset, uint256 amount) internal {
        accounts[id].assets[asset] += amount;
    }

    /* Getters */
    function getAccountLender(bytes32 id) public view returns (address) {
        return accounts[id].lender;
    }

    function getAccountAssetAmount(bytes32 id, address asset) public view returns (uint256) {
        return accounts[id].assets[asset];
    }

    // TODO: This should be more efficient.
    function isAcceptableTermSheet(bytes32 id, bytes32 termSheet) public view returns (bool) {
        for (uint256 i = 0; i < accounts[id].allowedTermSheets.length; i++) {
            if (termSheet == accounts[id].allowedTermSheets[i]) {
                return true;
            }
        }
        return false;
    }
}
