// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * An account holding Lender capital that can be taken as a loan. An Offer Account has only
 * one lender, but each lender can have an arbitrary amount of Offer Accounts.
 * Can accept any erc20 asset, though it may not be useable.
 */
struct OfferAccount {
    address lender;
    bool active;
    mapping(address => uint256) assets;
    /* Modules */
    bytes32 oracleSet;
    address minAssessor; // Least expensive assessor of this type willing to use
    bytes32 terminalSet;
    address maxLiquidator; // Most expensive liquidator instance of this type willing to use
    /* Scope */
    uint256 maxCollateralizationRatio;
    uint256 maxDuration;
    // uint256 minDuration;
    address[] allowedBorrowers;
    bytes32 allowedCollateralAssetSet;
}

/**
 * contract OfferAccountRegistry {
 *     mapping(bytes32 => OfferAccount) private accounts; // Disable getters/setters
 *     uint256 public accountCount;
 *     // mapping(address => bytes32[]) lenderOfferAccounts;
 * 
 *     event OfferAccountCreated(address, bytes32);
 *     event OfferAssetsAdded(bytes32, address, uint256);
 *     event OfferAssetsRemoved(bytes32, address, uint256);
 * 
 *     function createOfferAccount(
 *         bytes32 id,
 *         address[] calldata assets,
 *         uint256[] calldata amounts
 *     ) public {
 *         require(accounts[id].lender == address(0));
 *         // accounts[id] = OfferAccount({lender: msg.sender, allowedTermSheets: termSheets});
 *         OfferAccount storage account = accounts[id];
 *         account.lender = msg.sender;
 *         accountCount++;
 *         emit OfferAccountCreated(msg.sender, id);
 *         addOfferAssets(id, assets, amounts);
 *     }
 * 
 *     function addOfferAssets(bytes32 id, address[] calldata assets, uint256[] calldata amounts) public {
 *         require(accounts[id].lender == msg.sender);
 *         for (uint256 i; i < assets.length; i++) {
 *             accounts[id].assets[assets[i]] += amounts[i];
 *             require(IERC20(assets[i]).transferFrom(msg.sender, address(this), amounts[i]));
 *             emit OfferAssetsAdded(id, assets[i], amounts[i]);
 *         }
 *     }
 * 
 *     function removeOfferAssets(bytes32 id, address[] calldata assets, uint256[] calldata amounts) public {
 *         require(accounts[id].lender == msg.sender);
 *         for (uint256 i; i < assets.length; i++) {
 *             accounts[id].assets[assets[i]] -= amounts[i]; // includes overflow check.
 *             require(IERC20(assets[i]).transfer(msg.sender, amounts[i]));
 *             emit OfferAssetsRemoved(id, assets[i], amounts[i]);
 *         }
 *     }
 * 
 *     function decrementOfferAssets(bytes32 id, address asset, uint256 amount) internal {
 *         accounts[id].assets[asset] -= amount; // includes overflow check.
 *     }
 * 
 *     function incrementOfferAssets(bytes32 id, address asset, uint256 amount) internal {
 *         accounts[id].assets[asset] += amount;
 *     }
 * 
 *     function getAccountLender(bytes32 id) public view returns (address) {
 *         return accounts[id].lender;
 *     }
 * 
 *     function getAccountAssetAmount(bytes32 id, address asset) public view returns (uint256) {
 *         return accounts[id].assets[asset];
 *     }
 * 
 * }
 */
