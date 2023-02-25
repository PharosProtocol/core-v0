// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * An account holding Borrower capital that can be deployed as collateral. A Request Account has only
 * one Borrower, but each Borrower can have an arbitrary amount of Request Accounts.
 * Can accept any erc20 asset, though it may not be useable.
 */
struct RequestAccount {
    address borrower;
    bool active;
    mapping(address => uint256) collateralAssets;
    /* Modules */
    bytes32 oracleSet;
    address maxAssessor; // Most expensive assessor of this type willing to use
    address minLiquidator; // Least expensive liquidator of this type willing to use
    bytes32 allowedTerminalSet;
    /* Scope */
    uint256 collateralizationRatio;
    uint256 minDuration;
    // uint256 maxDuration;
    address[] allowedLenders;
    bytes32 allowedLoanAssetSet;
}

/**
 * contract RequestAccountRegistry {
 *     mapping(bytes32 => RequestAccount) public accounts;
 *     // uint256 internal accountCount;
 * 
 *     event RequestAccountCreated(address, bytes32);
 *     event RequestAssetsAdded(bytes32, address, uint256);
 *     event RequestAssetsRemoved(bytes32, address, uint256);
 * 
 *     function createRequestAccount(
 *         bytes32 id,
 *         address[] calldata assets,
 *         uint256[] calldata amounts,
 *         bytes32 allowedTerminalSet,
 *         uint256 collateralizationRatio
 *     ) public {
 *         require(accounts[id].borrower == address(0));
 *         // accounts[id] = RequestAccount({lendee: msg.sender, allowedTermSheets: termSheets});
 *         RequestAccount storage account = accounts[id];
 *         account.borrower = msg.sender;
 *         account.allowedTerminalSet = allowedTerminalSet;
 *         account.collateralizationRatio = collateralizationRatio;
 * 
 *         // accountCount++;
 *         emit RequestAccountCreated(msg.sender, id);
 *         addRequestAssets(id, assets, amounts);
 *     }
 * 
 *     function addRequestAssets(bytes32 id, address[] calldata assets, uint256[] calldata amounts) public {
 *         require(accounts[id].borrower == msg.sender);
 *         for (uint256 i; i < assets.length; i++) {
 *             accounts[id].collateralAssets[assets[i]] += amounts[i];
 *             require(IERC20(assets[i]).transferFrom(msg.sender, address(this), amounts[i]));
 *             emit RequestAssetsAdded(id, assets[i], amounts[i]);
 *         }
 *     }
 * 
 *     function removeRequestAssets(bytes32 id, address[] calldata assets, uint256[] calldata amounts) public {
 *         require(accounts[id].borrower == msg.sender);
 *         for (uint256 i; i < assets.length; i++) {
 *             accounts[id].collateralAssets[assets[i]] -= amounts[i];
 *             require(accounts[id].collateralAssets[assets[i]] >= 0);
 *             require(IERC20(assets[i]).transfer(msg.sender, amounts[i]));
 *             emit RequestAssetsRemoved(id, assets[i], amounts[i]);
 *         }
 *     }
 * 
 *     function decrementRequestAssets(bytes32 id, address asset, uint256 amount) internal {
 *         accounts[id].collateralAssets[asset] -= amount; // includes overflow check.
 *     }
 * 
 *     function incrementRequestAssets(bytes32 id, address asset, uint256 amount) internal {
 *         accounts[id].collateralAssets[asset] += amount;
 *     }
 * 
 *     function getAccountBorrower(bytes32 id) public view returns (address) {
 *         return accounts[id].borrower;
 *     }
 * }
 */
