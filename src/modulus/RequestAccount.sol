// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * An account holding Lendee capital that can be deployed as collateral. A Request Account has only
 * one Lendee, but each Lendee can have an arbitrary amount of Request Accounts.
 * Can accept any erc20 asset, though it may not be useable.
 * Assets are pushed/pulled by Lendee and Term Sheet.
 */
struct RequestAccount {
    address borrower;
    // Term sheets with which *new* positions can be opened.
    bytes32[] allowedTermSheets;
    // Current balance of assets.
    mapping(address => uint256) assets;
    // Terminal at which to open position at when loan is provided.
    address targetTerminal;
}
// enum status;

/**
 *
 */
contract RequestAccountRegistry {
    event RequestAccountCreated(address, bytes32);
    event RequestAssetsAdded(bytes32, address, uint256);
    event RequestAssetsRemoved(bytes32, address, uint256);

    mapping(bytes32 => RequestAccount) private accounts;
    uint256 public accountCount;

    function createRequestAccount(
        bytes32 id,
        bytes32[] calldata termSheets,
        address[] calldata assets,
        uint256[] calldata amounts
    ) public {
        require(accounts[id].borrower == address(0));
        // accounts[id] = RequestAccount({lendee: msg.sender, allowedTermSheets: termSheets});
        RequestAccount storage account = accounts[id];
        account.borrower = msg.sender;
        account.allowedTermSheets = termSheets;
        accountCount++;
        emit RequestAccountCreated(msg.sender, id);
        addRequestAssets(id, assets, amounts);
    }

    function addRequestAssets(bytes32 id, address[] calldata assets, uint256[] calldata amounts) public {
        require(accounts[id].borrower == msg.sender);
        for (uint256 i; i < assets.length; i++) {
            accounts[id].assets[assets[i]] += amounts[i];
            require(IERC20(assets[i]).transferFrom(msg.sender, address(this), amounts[i]));
            emit RequestAssetsAdded(id, assets[i], amounts[i]);
        }
    }

    function removeRequestAssets(bytes32 id, address[] calldata assets, uint256[] calldata amounts) public {
        require(accounts[id].borrower == msg.sender);
        for (uint256 i; i < assets.length; i++) {
            accounts[id].assets[assets[i]] -= amounts[i];
            require(accounts[id].assets[assets[i]] >= 0);
            require(IERC20(assets[i]).transfer(msg.sender, amounts[i]));
            emit RequestAssetsRemoved(id, assets[i], amounts[i]);
        }
    }

    function setAllowedTermSheets(bytes32 id, bytes32[] calldata termSheets) public {
        require(accounts[id].borrower == msg.sender);
        accounts[id].allowedTermSheets = termSheets;
    }

    function decrementRequestAssets(bytes32 id, address asset, uint256 amount) internal {
        accounts[id].assets[asset] -= amount; // includes overflow check.
    }

    function incrementRequestAssets(bytes32 id, address asset, uint256 amount) internal {
        accounts[id].assets[asset] += amount;
    }

    /* Getters */
    function getAccountBorrower(bytes32 id) public view returns (address) {
        return accounts[id].borrower;
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
